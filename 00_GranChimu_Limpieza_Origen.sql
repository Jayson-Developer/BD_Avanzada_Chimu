-- PRÁCTICA DE CAMPO 3 | PUESTO DE SALUD GRAN CHIMÚ (CASO ACADÉMICO)
-- SCRIPT 0: LIMPIEZA DE LA BASE DE ORIGEN (BI_GranChimu)
--
-- CUÁNDO USARLO: si en BI_GranChimu quedaron tablas de intentos anteriores (por ejemplo, las del script
-- "script_sql_completo_bi_gran_chimu_Modificado_2") o una ejecución incompleta del script 02.
--
-- QUÉ BORRA: todas las tablas y vistas de dimensiones y hechos de la base de origen, tanto del modelo
-- anterior (DimPacientes, FactAtenciones...) como del script 02 (Atenciones, Citas...).
-- QUÉ CONSERVA: dbo.Pacientes con sus 400 pacientes y la vista dbo.vw_PacientesBI (script 1).
-- Quita de Pacientes las columnas SectorID y SeguroID, que el script 02 vuelve a crear.
--
-- Después de ejecutarlo, ejecute de nuevo el script 02 completo.

USE BI_GranChimu;
GO

-- 1. Vistas que dependen de las tablas.
DROP VIEW IF EXISTS dbo.vw_SeguimientoCitas, dbo.vw_FactCitas, dbo.vw_FactDiagnosticos, dbo.vw_FactAtenciones,
                    dbo.vw_DimPaciente, dbo.vw_MapaPaciente, dbo.vw_ResumenAtencionesBI;
GO

-- 2. Claves foráneas que apuntan desde Pacientes hacia los catálogos.
ALTER TABLE dbo.Pacientes DROP CONSTRAINT IF EXISTS FK_Pacientes_Sector, FK_Pacientes_Seguro;
GO

-- 3. Tablas del script 02 (primero las que referencian a otras).
DROP TABLE IF EXISTS dbo.DiagnosticosAtencion;
DROP TABLE IF EXISTS dbo.Atenciones;
DROP TABLE IF EXISTS dbo.Citas;

-- 4. Tablas del modelo anterior (hechos primero, luego dimensiones).
DROP TABLE IF EXISTS dbo.FactDiagnosticos;
DROP TABLE IF EXISTS dbo.FactCitas;
DROP TABLE IF EXISTS dbo.FactAtenciones;
DROP TABLE IF EXISTS dbo.DimPacientes;
DROP TABLE IF EXISTS dbo.DimProfesional;

-- 5. Catálogos (comunes a ambos modelos, con estructuras distintas).
DROP TABLE IF EXISTS dbo.DimDiagnostico;
DROP TABLE IF EXISTS dbo.DimServicio;
DROP TABLE IF EXISTS dbo.DimSector;
DROP TABLE IF EXISTS dbo.DimSeguro;
DROP TABLE IF EXISTS dbo.DimTipoAtencion;
DROP TABLE IF EXISTS dbo.DimEstadoCita;
DROP TABLE IF EXISTS dbo.DimGrupoEtario;
DROP TABLE IF EXISTS dbo.DimFecha;
GO

-- 6. Columnas que el script 02 agregó a Pacientes (se crean de nuevo al ejecutarlo).
IF COL_LENGTH(N'dbo.Pacientes', N'SectorID') IS NOT NULL
    ALTER TABLE dbo.Pacientes DROP COLUMN SectorID;
IF COL_LENGTH(N'dbo.Pacientes', N'SeguroID') IS NOT NULL
    ALTER TABLE dbo.Pacientes DROP COLUMN SeguroID;
GO

-- 7. COMPROBACIÓN: debe quedar solo Pacientes, con 400 filas.
SELECT name AS TablaRestante FROM sys.tables ORDER BY name;
SELECT COUNT(*) AS TotalPacientes FROM dbo.Pacientes;   -- 400
GO
