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
