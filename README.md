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
