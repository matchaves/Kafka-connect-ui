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
