@echo off
REM scripts\migrate.bat
REM Aplica todas las migraciones, en orden, contra el contenedor de Postgres.
REM Uso (desde la carpeta renta-ia-database, en cmd.exe):
REM     scripts\migrate.bat

setlocal enabledelayedexpansion

set CONTAINER=renta_ia_postgres
set DB_NAME=renta_ia
set DB_USER=postgres

echo Aplicando migraciones...

for %%f in (migrations\*.sql) do (
    echo -^> ejecutando %%f
    docker exec -i %CONTAINER% psql -U %DB_USER% -d %DB_NAME% < "%%f"
    if errorlevel 1 (
        echo ERROR al ejecutar %%f
        exit /b 1
    )
)

echo Migraciones aplicadas correctamente.
