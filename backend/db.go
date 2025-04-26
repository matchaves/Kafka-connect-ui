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
