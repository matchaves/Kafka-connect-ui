#!/bin/bash

# Atualiza list_files.html para usar uma lista em vez de caixa de seleção
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

        <ul id="file-list" class="space-y-2">
            <!-- Arquivos serão inseridos aqui -->
        </ul>
        <div id="file-list-data" hx-get="/api/files" hx-trigger="load" hx-swap="none"></div>
        <script>
            document.getElementById('file-list-data').addEventListener('htmx:afterRequest', function(evt) {
                if (evt.detail.xhr.response) {
                    const files = JSON.parse(evt.detail.xhr.response);
                    const ul = document.getElementById('file-list');
                    ul.innerHTML = ''; // Limpa a lista existente
                    files.forEach(file => {
                        const li = document.createElement('li');
                        const a = document.createElement('a');
                        a.href = `/edit/${file}`;
                        a.textContent = file;
                        a.className = 'text-blue-500 hover:underline';
                        a.setAttribute('hx-get', `/edit/${file}`);
                        a.setAttribute('hx-target', '#main-container');
                        li.appendChild(a);
                        ul.appendChild(li);
                    });
                }
            });
        </script>
    </div>
</div>
EOF

echo "Atualizado list_files.html para usar uma lista em vez de caixa de seleção."