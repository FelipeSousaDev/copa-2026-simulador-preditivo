import sqlalchemy
import pandas as pd 

SERVER = 'FELIPE-PC\SQLEXPRESS'
DATABASE = 'master'


#string
connection_url = f"mssql+pyodbc://@{SERVER}/{DATABASE}?driver=ODBC+Driver+17+for+SQL+Server&trusted_connection=yes"

print('Tentando conexão')

try:
    engine = sqlalchemy.create_engine(connection_url)
    print('Conexão bem sucedida')

    df = pd.read_sql('SELECT 1 as status', engine)
    
    if df['status'].iloc[0] == 1:
        
        print('Conexão com o banco de dados estabelecida e testada com sucesso!')
        
except Exception as e:
    print('Erro de conexão')
