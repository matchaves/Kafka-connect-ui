package main

import (
	"bytes"
	"database/sql"
	"fmt"
	"io"
	"net/http"
	"text/template"

	_ "github.com/mattn/go-sqlite3"
)

var kafkaConnectURL = "http://localhost:8083" // ajuste para o seu Kafka Connect

type ConnectorConfig struct {
	Name   string
	Config map[string]interface{}
}

var db *sql.DB

func main() {
	var err error
	db, err = sql.Open("sqlite3", "./connectors.db")
	if err != nil {
		panic(err)
	}
	defer db.Close()

	// Criar tabela caso não exista
	_, err = db.Exec(`
		CREATE TABLE IF NOT EXISTS connectors (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			name TEXT,
			config TEXT
		)
	`)
	if err != nil {
		panic(err)
	}

	http.HandleFunc("/", handleHome)
	http.HandleFunc("/load", handleLoadConnector)
	http.HandleFunc("/update", handleUpdateConnector)
	http.Handle("/static/", http.StripPrefix("/static/", http.FileServer(http.Dir("./static"))))

	fmt.Println("Servidor rodando em http://localhost:3000")
	http.ListenAndServe(":3000", nil)
}

func handleHome(w http.ResponseWriter, r *http.Request) {
	tmpl := template.Must(template.ParseFiles("./templates/index.html"))
	tmpl.Execute(w, nil)
}

func handleLoadConnector(w http.ResponseWriter, r *http.Request) {
	connectorName := r.URL.Query().Get("name")
	resp, err := http.Get(fmt.Sprintf("%s/connectors/%s/config", kafkaConnectURL, connectorName))
	if err != nil {
		http.Error(w, "Erro ao buscar connector", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)

	// Renderizar um <textarea> com o conteúdo para o HTMX substituir
	w.Header().Set("Content-Type", "text/html")
	fmt.Fprintf(w, `<textarea id="editor-json" name="json" style="display:none;">%s</textarea>
<div id="editor"></div>

<script>
    if (window.editor) {
        editor.toTextArea();
    }
    editor = CodeMirror.fromTextArea(document.getElementById("editor-json"), {
        lineNumbers: true,
        mode: "application/json",
        theme: "default"
    });
</script>`, body)
}


func handleUpdateConnector(w http.ResponseWriter, r *http.Request) {
	connectorName := r.URL.Query().Get("name")
	body, _ := io.ReadAll(r.Body)

	// Salvar no banco
	_, err := db.Exec("INSERT INTO connectors (name, config) VALUES (?, ?)", connectorName, string(body))
	if err != nil {
		http.Error(w, "Erro ao salvar no banco", http.StatusInternalServerError)
		return
	}

	// Aplicar no Kafka Connect
	req, _ := http.NewRequest("PUT", fmt.Sprintf("%s/connectors/%s/config", kafkaConnectURL, connectorName), bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		http.Error(w, "Erro ao atualizar connector", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)
}
