-- Script executado automaticamente na primeira inicialização do banco.
-- Ajuste conforme o esquema real da aplicação.

CREATE TABLE IF NOT EXISTS exemplo (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    criado_em TIMESTAMP NOT NULL DEFAULT NOW()
);
