@echo off
REM scripts\seed.bat
REM Carga los datos de prueba dentro del contenedor de Postgres.
REM Uso (desde la carpeta renta-ia-database, en cmd.exe):
REM     scripts\seed.bat

setlocal enabledelayedexpansion

set CONTAINER=renta_ia_postgres
set DB_NAME=renta_ia
set DB_USER=postgres

echo Cargando datos de prueba...

for %%f in (seed\*.sql) do (
    echo -^> cargando %%f
    docker exec -i %CONTAINER% psql -U %DB_USER% -d %DB_NAME% < "%%f"
    if errorlevel 1 (
        echo ERROR al cargar %%f
        exit /b 1
    )
)

echo Datos de prueba cargados correctamente.
