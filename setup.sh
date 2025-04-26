#!/bin/bash

# Script para criar a estrutura do projeto JSON Editor com HTMX
# Arquivos são criados no mesmo nível do script

# Criar estrutura de pastas
mkdir -p backend
mkdir -p frontend/static/codemirror
mkdir -p frontend/templates

# Criar arquivos do backend
cat << 'EOF' > backend/main.go
package main

import (
    "log"
    "net/http"
    "html/template"
    "github.com/gorilla/mux"
)

var templates *template.Template

func main() {
    log.Println("Initializing database...")
    InitDB()
    defer CloseDB()

    // Carregar templates
    log.Println("Loading templates from ../frontend/templates/")
    templates = template.Must(template.ParseGlob("../frontend/templates/*.html"))

    router := mux.NewRouter()
    
    // API endpoints
    router.HandleFunc("/api/files", GetFiles).Methods("GET")
    router.HandleFunc("/api/file/{name}", GetFile).Methods("GET")
    router.HandleFunc("/api/file", SaveFile).Methods("POST")
    
    // Rotas de template
    router.HandleFunc("/", RenderHome).Methods("GET")
    router.HandleFunc("/list", RenderListFiles).Methods("GET")
    router.HandleFunc("/create", RenderCreateFile).Methods("GET")
    router.HandleFunc("/edit/{name}", RenderEditFile).Methods("GET")
    
    // Servir arquivos estáticos
    router.PathPrefix("/static/").Handler(http.StripPrefix("/static/", http.FileServer(http.Dir("../frontend/static"))))
    
    log.Println("Server starting on :8080")
    log.Fatal(http.ListenAndServe(":8080", router))
}

func RenderHome(w http.ResponseWriter, r *http.Request) {
    log.Println("Rendering home page")
    templates.ExecuteTemplate(w, "home.html", nil)
}

func RenderListFiles(w http.ResponseWriter, r *http.Request) {
    log.Println("Rendering list files page")
    templates.ExecuteTemplate(w, "list_files.html", nil)
}

func RenderCreateFile(w http.ResponseWriter, r *http.Request) {
    log.Println("Rendering create file page")
    templates.ExecuteTemplate(w, "create_file.html", nil)
}

func RenderEditFile(w http.ResponseWriter, r *http.Request) {
    vars := mux.Vars(r)
    name := vars["name"]
    log.Printf("Rendering edit page for file: %s", name)
    templates.ExecuteTemplate(w, "edit_file.html", map[string]string{"FileName": name})
}
EOF

cat << 'EOF' > backend/db.go
package main

import (
    "database/sql"
    _ "github.com/mattn/go-sqlite3"
    "log"
)

var db *sql.DB

type File struct {
    Name    string `json:"name"`
    Content string `json:"content"`
}

func InitDB() {
    var err error
    log.Println("Opening SQLite database at ./files.db")
    db, err = sql.Open("sqlite3", "./files.db")
    if err != nil {
        log.Fatalf("Failed to open database: %v", err)
    }

    // Verificar conexão
    if err = db.Ping(); err != nil {
        log.Fatalf("Failed to ping database: %v", err)
    }

    createTable := `
    CREATE TABLE IF NOT EXISTS files (
        name TEXT PRIMARY KEY,
        content TEXT
    );`
    
    log.Println("Creating files table if not exists")
    _, err = db.Exec(createTable)
    if err != nil {
        log.Fatalf("Failed to create table: %v", err)
    }
}

func CloseDB() {
    log.Println("Closing database connection")
    db.Close()
}
EOF

cat << 'EOF' > backend/handlers.go
package main

import (
    "encoding/json"
    "log"
    "net/http"
    "github.com/gorilla/mux"
)

func GetFiles(w http.ResponseWriter, r *http.Request) {
    log.Println("Fetching list of files from database")
    rows, err := db.Query("SELECT name FROM files")
    if err != nil {
        log.Printf("Error fetching files from database: %v", err)
        http.Error(w, "Failed to fetch files", http.StatusInternalServerError)
        return
    }
    defer rows.Close()

    var files []string
    for rows.Next() {
        var name string
        if err := rows.Scan(&name); err != nil {
            log.Printf("Error scanning file name: %v", err)
            continue
        }
        files = append(files, name)
    }
    if err := rows.Err(); err != nil {
        log.Printf("Error iterating over files: %v", err)
    }
    log.Printf("Retrieved %d files: %v", len(files), files)

    w.Header().Set("Content-Type", "application/json")
    if err := json.NewEncoder(w).Encode(files); err != nil {
        log.Printf("Error encoding files response: %v", err)
        http.Error(w, "Failed to encode response", http.StatusInternalServerError)
    }
}

func GetFile(w http.ResponseWriter, r *http.Request) {
    vars := mux.Vars(r)
    name := vars["name"]
    log.Printf("Fetching file: %s", name)

    var file File
    err := db.QueryRow("SELECT name, content FROM files WHERE name = ?", name).Scan(&file.Name, &file.Content)
    if err != nil {
        log.Printf("Error fetching file %s: %v", name, err)
        http.Error(w, "File not found", http.StatusNotFound)
        return
    }
    log.Printf("Retrieved file: %s\nContent: %s", file.Name, file.Content)

    w.Header().Set("Content-Type", "application/json")
    if err := json.NewEncoder(w).Encode(file); err != nil {
        log.Printf("Error encoding file response: %v", err)
        http.Error(w, "Failed to encode response", http.StatusInternalServerError)
    }
}

func SaveFile(w http.ResponseWriter, r *http.Request) {
    var file File
    if err := json.NewDecoder(r.Body).Decode(&file); err != nil {
        log.Printf("Error decoding save request: %v", err)
        http.Error(w, "Invalid request body", http.StatusBadRequest)
        return
    }
    log.Printf("Attempting to save file: %s\nContent: %s", file.Name, file.Content)

    // Validar JSON
    var jsonData interface{}
    if err := json.Unmarshal([]byte(file.Content), &jsonData); err != nil {
        log.Printf("Invalid JSON content for file %s: %v", file.Name, err)
        http.Error(w, "Content must be valid JSON", http.StatusBadRequest)
        return
    }

    result, err := db.Exec("INSERT OR REPLACE INTO files (name, content) VALUES (?, ?)", file.Name, file.Content)
    if err != nil {
        log.Printf("Error saving file %s: %v", file.Name, err)
        http.Error(w, "Failed to save file", http.StatusInternalServerError)
        return
    }

    rowsAffected, _ := result.RowsAffected()
    log.Printf("File %s saved successfully, rows affected: %d", file.Name, rowsAffected)

    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusOK)
    response := map[string]string{
        "message": "File saved successfully",
        "name":    file.Name,
    }
    if err := json.NewEncoder(w).Encode(response); err != nil {
        log.Printf("Error encoding save response: %v", err)
    }
}
EOF

cat << 'EOF' > backend/go.mod
module json-editor

go 1.21

require (
    github.com/gorilla/mux v1.8.1
    github.com/mattn/go-sqlite3 v1.14.22
)
EOF

# Criar arquivos do frontend
cat << 'EOF' > frontend/static/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>JSON Editor</title>
    <link rel="stylesheet" href="/static/styles.css">
    <link rel="stylesheet" href="/static/codemirror/codemirror.min.css">
    <script src="https://unpkg.com/htmx.org@1.9.10"></script>
    <script src="/static/codemirror/codemirror.min.js"></script>
    <script src="/static/codemirror/mode/javascript/javascript.min.js"></script>
    <link rel="stylesheet" href="/static/codemirror/theme/monokai.min.css">
</head>
<body>
    <div id="main-container" hx-get="/" hx-trigger="load"></div>
    <script>
        document.body.addEventListener('htmx:afterSwap', function() {
            const textarea = document.querySelector('#json-editor');
            if (textarea && !textarea.CodeMirror) {
                const editor = CodeMirror.fromTextArea(textarea, {
                    lineNumbers: true,
                    mode: 'application/json',
                    theme: 'monokai'
                });
                editor.on('change', () => {
                    textarea.value = editor.getValue();
                });
            }
        });
        document.body.addEventListener('htmx:afterRequest', function(evt) {
            if (evt.detail.xhr.response && evt.detail.xhr.response.includes('"content"')) {
                const response = JSON.parse(evt.detail.xhr.response);
                const textarea = document.querySelector('#json-editor');
                if (textarea && textarea.CodeMirror) {
                    textarea.CodeMirror.setValue(response.content || '{}');
                } else if (textarea) {
                    textarea.value = response.content || '{}';
                }
            }
        });
    </script>
</body>
</html>
EOF

cat << 'EOF' > frontend/templates/home.html
<div class="min-h-screen bg-gray-100 p-4">
    <div class="max-w-4xl mx-auto">
        <h1 class="text-2xl font-bold mb-4">JSON Editor</h1>
        
        <div class="flex flex-col space-y-4">
            <a 
                href="/list" 
                class="bg-blue-500 text-white p-4 rounded hover:bg-blue-600 text-center"
                hx-get="/list"
                hx-target="#main-container"
            >
                Listar Arquivos
            </a>
            <a 
                href="/create" 
                class="bg-green-500 text-white p-4 rounded hover:bg-green-600 text-center"
                hx-get="/create"
                hx-target="#main-container"
            >
                Criar Novo Arquivo
            </a>
            <a 
                href="/list" 
                class="bg-yellow-500 text-white p-4 rounded hover:bg-yellow-600 text-center"
                hx-get="/list"
                hx-target="#main-container"
            >
                Editar Arquivos
            </a>
        </div>
    </div>
</div>
EOF

cat << 'EOF' > frontend/templates/list_files.html
<div class="min-h-screen bg-gray-100 p-4">
    <div class="max-w-4xl mx-auto">
        <h1 class="text-2xl font-bold mb-4">Listar Arquivos JSON</h1>
        
        <div class="mb-4">
            <a 
                href="/" 
                class="bg-gray-500 text-white p-2 rounded hover:bg-gray-600"
                hx-get="/"
                hx-target="#main-container"
            >
                Voltar
            </a>
        </div>

        <div class="mb-4">
            <select 
                id="file-select" 
                class="p-2 border rounded w-64"
                hx-get="/edit/{value}"
                hx-target="#main-container"
                hx-trigger="change"
                name="file"
            >
                <option value="">Select a file</option>
            </select>
            <div id="file-list" hx-get="/api/files" hx-trigger="load" hx-swap="none"></div>
            <script>
                document.getElementById('file-list').addEventListener('htmx:afterRequest', function(evt) {
                    if (evt.detail.xhr.response) {
                        const files = JSON.parse(evt.detail.xhr.response);
                        const select = document.getElementById('file-select');
                        files.forEach(file => {
                            const option = document.createElement('option');
                            option.value = file;
                            option.textContent = file;
                            select.appendChild(option);
                        });
                    }
                });
            </script>
        </div>
    </div>
</div>
EOF

cat << 'EOF' > frontend/templates/create_file.html
<div class="min-h-screen bg-gray-100 p-4">
    <div class="max-w-4xl mx-auto">
        <h1 class="text-2xl font-bold mb-4">Criar Novo Arquivo JSON</h1>
        
        <div class="mb-4">
            <a 
                href="/" 
                class="bg-gray-500 text-white p-2 rounded hover:bg-gray-600"
                hx-get="/"
                hx-target="#main-container"
            >
                Voltar
            </a>
        </div>

        <form hx-post="/api/file" hx-target="#main-container" hx-swap="innerHTML" hx-encoding="multipart/form-data">
            <div class="mb-4">
                <input
                    type="text"
                    class="p-2 border rounded w-64"
                    id="file-name"
                    name="name"
                    placeholder="File name (e.g., config.json)"
                    required
                >
                <button
                    type="submit"
                    class="ml-2 bg-blue-500 text-white p-2 rounded hover:bg-blue-600"
                >
                    Save
                </button>
            </div>
            <textarea id="json-editor" name="content">{"example": "value"}</textarea>
        </form>
    </div>
</div>
EOF

cat << 'EOF' > frontend/templates/edit_file.html
<div class="min-h-screen bg-gray-100 p-4">
    <div class="max-w-4xl mx-auto">
        <h1 class="text-2xl font-bold mb-4">Editar Arquivo JSON</h1>
        
        <div class="mb-4">
            <a 
                href="/" 
                class="bg-gray-500 text-white p-2 rounded hover:bg-gray-600"
                hx-get="/"
                hx-target="#main-container"
            >
                Voltar
            </a>
        </div>

        <div class="mb-4">
            <form hx-post="/api/file" hx-target="#main-container" hx-swap="innerHTML" hx-encoding="multipart/form-data">
                <input
                    type="text"
                    class="p-2 border rounded w-64"
                    id="file-name"
                    name="name"
                    value="{{.FileName}}"
                    required
                >
                <button
                    type="submit"
                    class="ml-2 bg-blue-500 text-white p-2 rounded hover:bg-blue-600"
                >
                    Save
                </button>
                <textarea id="json-editor" name="content"></textarea>
            </form>
            <div id="file-content" hx-get="/api/file/{{.FileName}}" hx-trigger="load" hx-swap="none"></div>
            <script>
                document.getElementById('file-content').addEventListener('htmx:afterRequest', function(evt) {
                    if (evt.detail.xhr.response) {
                        const response = JSON.parse(evt.detail.xhr.response);
                        const textarea = document.getElementById('json-editor');
                        if (textarea && textarea.CodeMirror) {
                            textarea.CodeMirror.setValue(response.content || '{}');
                        } else {
                            textarea.value = response.content || '{}';
                        }
                    }
                });
            </script>
        </div>
    </div>
</div>
EOF

cat << 'EOF' > frontend/templates/file_list.html
{{range .}}
    <option value="{{.}}">{{.}}</option>
{{end}}
EOF

cat << 'EOF' > frontend/static/styles.css
@tailwind base;
@tailwind components;
@tailwind utilities;

.CodeMirror {
    height: 500px !important;
    border: 1px solid #ddd;
}
EOF

# Criar README
cat << 'EOF' > README.md
# JSON Editor com HTMX

## Instruções de Configuração

1. **Backend**:
   - Instale Go: `go version` (1.21 ou superior)
   - Navegue até o diretório `backend`
   - Rode `go mod tidy` para instalar dependências
   - Execute `go run main.go` para iniciar o servidor

2. **Frontend**:
   - Baixe os arquivos do CodeMirror (codemirror.min.js, codemirror.min.css, javascript.min.js, monokai.min.css) e coloque em `frontend/static/codemirror`
   - Não é necessário Node.js, pois usamos HTMX e CodeMirror via CDN

3. **Dependências**:
   - SQLite (via go-sqlite3)
   - Gorilla Mux para roteamento
   - HTMX para interatividade
   - CodeMirror para o editor
   - Tailwind CSS (via CDN)

4. **Uso**:
   - Acesse `http://localhost:8080`
   - Página inicial: Escolha entre "Listar Arquivos", "Criar Novo Arquivo" ou "Editar Arquivos"
   - Criar: Insira um nome e conteúdo JSON, salve
   - Listar/Editar: Selecione um arquivo da lista para editar
   - Verifique os logs no terminal para ações (salvar, buscar, editar)

**Nota**: Baixe os arquivos do CodeMirror de https://codemirror.net/5/
EOF

# Mensagem de conclusão
echo "Estrutura do projeto JSON Editor criada com sucesso no diretório atual!"
echo "Próximos passos:"
echo "1. Baixe os arquivos do CodeMirror e coloque em frontend/static/codemirror"
echo "2. Navegue até backend e execute 'go mod tidy'"
echo "3. Execute 'go run main.go' para iniciar o servidor"
echo "4. Acesse http://localhost:8080"