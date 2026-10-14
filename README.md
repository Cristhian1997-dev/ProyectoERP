# Proyecto ERP - Base de Datos I
 Proyecto académico desarrollado para el curso **Base de Datos I**, orientado al diseño e implementación de un ERP corporativo utilizando SQL Server.

 El proyecto fue desarrollado progresivamente en cuatro fases, incorporando diseño relacional, seguridad, transacciones ACID, procedimientos almacenados, triggers, auditoría, vistas indexadas y un frontend desarrollado con Streamlit.

## Tecnologías utilizadas

- SQL Server
- T-SQL
- Docker
- Docker Compose
- Ubuntu Server
- DBeaver
- Python
- Streamlit
- pymssql
- Git y GitHub

## Arquitectura utilizada

El entorno del proyecto se ejecuta sobre Ubuntu Server utilizando Docker Compose.

```text
Windows
    |
    | Navegador / DBeaver
Ubuntu Server
    |
Docker Compose
    |
    ├──sqlserver_clase1
    |   └── SQl Server 2022
    |       └── ERP_Corporativo
    |
    └── streamlit_clase1
        └──Python + Streamlit

