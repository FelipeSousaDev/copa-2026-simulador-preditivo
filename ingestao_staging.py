import pandas as pd
import sqlalchemy
import os
import glob

SERVER = 'FELIPE-PC\\SQLEXPRESS'
DATABASE = 'DB_COPA_2026'
CONNECTION_URL = f'mssql+pyodbc://@{SERVER}/{DATABASE}?driver=ODBC+Driver+17+for+SQL+Server&trusted_connection=yes'

CAMINHO_PARTIDAS = os.path.join('football_results', 'results.csv')
PASTA_RANKING = 'fifa_ranking'

def executar_ingestao_staging():
    try:
        engine = sqlalchemy.create_engine(CONNECTION_URL)
        print('🔌 Conexão iniciada com sucesso (: ')
        print('-' * 60)
        
        # --- FLUXO A: HISTÓRICO DE PARTIDAS ---
        if os.path.exists(CAMINHO_PARTIDAS):
            print(f'📦 Lendo arquivo de partidas: {CAMINHO_PARTIDAS}')
            df_partidas = pd.read_csv(CAMINHO_PARTIDAS)
            
            print('📤 Gravando dados na tabela [stg_partidas_internacionais]...')
            df_partidas.to_sql('stg_partidas_internacionais', engine, if_exists='replace', index=False)
            print(f'✅ Sucesso: {len(df_partidas)} registros carregados na Staging de Partidas.')
        else:
            print(f'❌ Erro: o arquivo {CAMINHO_PARTIDAS} não foi encontrado.')
            
        print('-' * 60)
        
        # --- FLUXO B: RANKING FIFA (CONCATENAR E INJETAR) ---
        padrao_busca = os.path.join(PASTA_RANKING, 'fifa_ranking_*.csv')
        arquivos_ranking = glob.glob(padrao_busca)
        
        if arquivos_ranking:
            print(f'📦 Localizados {len(arquivos_ranking)} arquivos de ranking, iniciando leitura...')
            lista_dataframes = []
            
            # O loop APENAS lê os arquivos e guarda na lista
            for arquivo in arquivos_ranking:
                print(f'  -> Processando: {arquivo} ...')
                df_temporario = pd.read_csv(arquivo)
                lista_dataframes.append(df_temporario)
            
            # AGORA SIM: Fora do loop, fazemos a junção e a carga UMA única vez
            print('🔀 Agrupando todos os dataframes em memória...')
            df_ranking = pd.concat(lista_dataframes, ignore_index=True)
            
            print('📤 Gravando dados consolidados na tabela [stg_ranking_fifa]...')
            df_ranking.to_sql('stg_ranking_fifa', engine, if_exists='replace', index=False)
            print(f'✅ Sucesso: {len(df_ranking)} registros totais carregados na Staging de Ranking.')
        else:
            print('❌ Erro: Nenhum arquivo de ranking foi localizado.')
            
    except Exception as e:
        print(f'🚨 Erro crítico durante a ingestão: {e}')
        
# CORREÇÃO DA ASSINATURA: Agora com as duas underscores necessárias
if __name__ == '__main__':
    executar_ingestao_staging()