-- ==============================================================================
-- SPRINT 2: TAREFA 2.1 - VIEW DE FEATURES COMPORTAMENTAIS PARA MACHINE LEARNING
-- ==============================================================================

USE DB_COPA_2026;
GO

DROP VIEW IF EXISTS vw_dados_treinamento;
GO

CREATE VIEW vw_dados_treinamento AS
WITH CTE_Base_Partidas AS (
    SELECT 
        p.ID_PARTIDA,
        p.DATA_PARTIDA,
        p.ID_SELECAO_MANDANTE,
        p.ID_SELECAO_VISITANTE,
        p.GOLS_MANDANTE,
        p.GOLS_VISITANTE,
        p.PESO_COMPETICAO,
        
        -- Alvo da IA (Target): 2 = Vitória Mandante, 1 = Empate, 0 = Vitória Visitante
        CASE 
            WHEN p.GOLS_MANDANTE > p.GOLS_VISITANTE THEN 2
            WHEN p.GOLS_MANDANTE = p.GOLS_VISITANTE THEN 1
            ELSE 0 
        END AS TARGET_RESULTADO,

        -- Define o semestre da partida para acoplamento com a granularidade do ranking
        CASE WHEN MONTH(p.DATA_PARTIDA) <= 6 THEN 1 ELSE 2 END AS SEMESTRE_PARTIDA,
        YEAR(p.DATA_PARTIDA) AS ANO_PARTIDA
    FROM fato_partidas p
),

CTE_Rankings_Calculados AS (
    SELECT 
        bp.*,
        -- Extração de pontos da FIFA usando a convenção de colunas com caracteres especiais [total.points]
        ISNULL(r_man.[total.points], 0) AS PONTOS_FIFA_MANDANTE,
        ISNULL(r_vis.[total.points], 0) AS PONTOS_FIFA_VISITANTE
    FROM CTE_Base_Partidas bp
    
    -- Associação de Ranking do Mandante pelo Ano e Semestre correspondentes
    LEFT JOIN stg_ranking_fifa r_man 
        ON r_man.team = (SELECT NOME_SELECAO FROM dim_selecoes WHERE ID_SELECAO = bp.ID_SELECAO_MANDANTE)
        AND r_man.date = bp.ANO_PARTIDA
        AND r_man.semester = bp.SEMESTRE_PARTIDA
        
    -- Associação de Ranking do Visitante pelo Ano e Semestre correspondentes
    LEFT JOIN stg_ranking_fifa r_vis 
        ON r_vis.team = (SELECT NOME_SELECAO FROM dim_selecoes WHERE ID_SELECAO = bp.ID_SELECAO_VISITANTE)
        AND r_vis.date = bp.ANO_PARTIDA
        AND r_vis.semester = bp.SEMESTRE_PARTIDA
)

SELECT 
    rc.ID_PARTIDA,
    rc.DATA_PARTIDA,
    rc.ID_SELECAO_MANDANTE,
    rc.ID_SELECAO_VISITANTE,
    rc.PESO_COMPETICAO,
    rc.TARGET_RESULTADO,
    
    -- FEATURE 1: Força Relativa (Valores positivos indicam favoritismo técnico do Mandante)
    (rc.PONTOS_FIFA_MANDANTE - rc.PONTOS_FIFA_VISITANTE) AS DELTA_RANKING_PONTOS,

    -- FEATURE 2: Média Móvel de Gols Marcados pelo Mandante (Últimos 24 meses)
    ISNULL(hist_man.GOLS_MARCADOS_24M, 0) AS MED_GOLS_MARCADOS_MANDANTE,

    -- FEATURE 3: Média Móvel de Gols Marcados pelo Visitante (Últimos 24 meses)
    ISNULL(hist_vis.GOLS_MARCADOS_24M, 0) AS MED_GOLS_MARCADOS_VISITANTE

FROM CTE_Rankings_Calculados rc

-- Janela de Cálculo para o Mandante (Varre jogos como mandante ou visitante nos últimos 24 meses)
CROSS APPLY (
    SELECT AVG(CAST(Gols_Marcados AS DECIMAL(5,2))) AS GOLS_MARCADOS_24M
    FROM (
        SELECT GOLS_MANDANTE AS Gols_Marcados FROM fato_partidas 
        WHERE ID_SELECAO_MANDANTE = rc.ID_SELECAO_MANDANTE AND DATA_PARTIDA < rc.DATA_PARTIDA AND DATA_PARTIDA >= DATEADD(MONTH, -24, rc.DATA_PARTIDA)
        UNION ALL
        SELECT GOLS_VISITANTE AS Gols_Marcados FROM fato_partidas 
        WHERE ID_SELECAO_VISITANTE = rc.ID_SELECAO_MANDANTE AND DATA_PARTIDA < rc.DATA_PARTIDA AND DATA_PARTIDA >= DATEADD(MONTH, -24, rc.DATA_PARTIDA)
    ) AS sub_man
) hist_man

-- Janela de Cálculo para o Visitante (Varre jogos como mandante ou visitante nos últimos 24 meses)
CROSS APPLY (
    SELECT AVG(CAST(Gols_Marcados AS DECIMAL(5,2))) AS GOLS_MARCADOS_24M
    FROM (
        SELECT GOLS_MANDANTE AS Gols_Marcados FROM fato_partidas 
        WHERE ID_SELECAO_MANDANTE = rc.ID_SELECAO_VISITANTE AND DATA_PARTIDA < rc.DATA_PARTIDA AND DATA_PARTIDA >= DATEADD(MONTH, -24, rc.DATA_PARTIDA)
        UNION ALL
        SELECT GOLS_VISITANTE AS Gols_Marcados FROM fato_partidas 
        WHERE ID_SELECAO_VISITANTE = rc.ID_SELECAO_VISITANTE AND DATA_PARTIDA < rc.DATA_PARTIDA AND DATA_PARTIDA >= DATEADD(MONTH, -24, rc.DATA_PARTIDA)
    ) AS sub_vis
) hist_vis

-- CORTE CRONOLÓGICO DA LINHA DE BASE: Filtra apenas futebol moderno para o treinamento da IA
WHERE YEAR(rc.DATA_PARTIDA) >= 2014;
GO

PRINT '✅ Tarefa 2.1 Concluída: vw_dados_treinamento gerada com features matemáticas.';
GO