-- =========================================================
-- SPRINT 1: TAREFA 1.3 - CRIAÇÃO DA FATO DE PARTIDAS
-- =========================================================

-- 1. Garante a limpeza do ambiente antes da criação
DROP TABLE IF EXISTS fato_partidas;
GO

-- 2. Criação da estrutura da tabela Fato com integridade referencial
CREATE TABLE fato_partidas (
    ID_PARTIDA INT IDENTITY(1,1) PRIMARY KEY,
    DATA_PARTIDA DATE NOT NULL,
    ID_SELECAO_MANDANTE INT NOT NULL,
    ID_SELECAO_VISITANTE INT NOT NULL,
    GOLS_MANDANTE INT NULL,
    GOLS_VISITANTE INT NULL,
    NOME_TORNEIO VARCHAR(100) NOT NULL,
    PESO_COMPETICAO INT NOT NULL,
    
    -- Definição das Restrições de Chave Estrangeira (FK)
    FOREIGN KEY (ID_SELECAO_MANDANTE) REFERENCES dim_selecoes(ID_SELECAO),
    FOREIGN KEY (ID_SELECAO_VISITANTE) REFERENCES dim_selecoes(ID_SELECAO)
);
GO

-- 3. Carga de dados associando chaves textuais aos IDs numéricos
INSERT INTO fato_partidas (
    DATA_PARTIDA, 
    ID_SELECAO_MANDANTE, 
    ID_SELECAO_VISITANTE, 
    GOLS_MANDANTE, 
    GOLS_VISITANTE, 
    NOME_TORNEIO, 
    PESO_COMPETICAO
)
SELECT 
    CAST(p.date AS DATE) AS DATA_PARTIDA,
    dm.ID_SELECAO AS ID_SELECAO_MANDANTE,
    dv.ID_SELECAO AS ID_SELECAO_VISITANTE,
    CAST(p.home_score AS INT) AS GOLS_MANDANTE,
    CAST(p.away_score AS INT) AS GOLS_VISITANTE,
    p.tournament AS NOME_TORNEIO,
    
    -- REGRA DE NEGÓCIO COMPREENSIVA DE PESO COMPETITIVO
    CASE 
        WHEN p.tournament = 'Friendly' THEN 1
        WHEN p.tournament = 'FIFA World Cup' THEN 3
        ELSE 2 -- Qualifiers, Euro, Copa América, etc.
    END AS PESO_COMPETICAO

FROM stg_partidas_internacionais p
-- Primeiro JOIN para buscar o ID do Mandante
INNER JOIN dim_selecoes dm ON TRIM(p.home_team) = dm.NOME_SELECAO
-- Segundo JOIN (Alias diferente) para buscar o ID do Visitante
INNER JOIN dim_selecoes dv ON TRIM(p.away_team) = dv.NOME_SELECAO
-- Data Quality: Ignora registros de jogos futuros ou sem placar preenchido
WHERE p.home_score IS NOT NULL AND p.away_score IS NOT NULL;
GO