-- PRÁCTICA DE CAMPO 3 | PUESTO DE SALUD GRAN CHIMÚ (CASO ACADÉMICO)
-- SCRIPT 4: VALIDACIÓN DEL ETL (ejecutar DESPUÉS de correr el paquete SSIS)
-- SQL Server 2022 | Compara el ORIGEN (BI_GranChimu) con el DW (BI_GranChimu_DW).
--
-- Cada consulta es una evidencia para el punto 4.6 del informe: tome una captura por bloque.
-- Los resultados esperados están indicados en cada sección. Si el nombre de su base de origen
-- es otro, reemplace BI_GranChimu en este archivo.

USE BI_GranChimu_DW;
GO

-- 1. BITÁCORA DE LA CARGA (una línea por flujo de datos del paquete SSIS).
SELECT LogID, Proceso, FechaEjecucion, FilasLeidas, FilasInsertadas, FilasRechazadas, Estado, Mensaje
FROM etl.LogCarga
ORDER BY LogID;
GO

-- 2. REGISTROS DE ENTRADA VS REGISTROS CARGADOS. Resultado esperado: Diferencia = 0 y Resultado = OK.
-- (Las dimensiones no cuentan el miembro "No especificado", clave -1.)
SELECT x.Objeto, x.FilasOrigen, x.FilasDW, x.FilasOrigen - x.FilasDW AS Diferencia,
       CASE WHEN x.FilasOrigen = x.FilasDW THEN N'OK' ELSE N'REVISAR' END AS Resultado
FROM
(
    SELECT N'Pacientes -> DimPaciente' AS Objeto,
           (SELECT COUNT(*) FROM BI_GranChimu.dbo.Pacientes) AS FilasOrigen,
           (SELECT COUNT(*) FROM dbo.DimPaciente WHERE PacienteKey > 0) AS FilasDW
    UNION ALL SELECT N'DimFecha -> DimFecha',
           (SELECT COUNT(*) FROM BI_GranChimu.dbo.DimFecha), (SELECT COUNT(*) FROM dbo.DimFecha)
    UNION ALL SELECT N'DimSector -> DimSector',
           (SELECT COUNT(*) FROM BI_GranChimu.dbo.DimSector), (SELECT COUNT(*) FROM dbo.DimSector WHERE SectorKey > 0)
    UNION ALL SELECT N'DimSeguro -> DimSeguro',
           (SELECT COUNT(*) FROM BI_GranChimu.dbo.DimSeguro), (SELECT COUNT(*) FROM dbo.DimSeguro WHERE SeguroKey > 0)
    UNION ALL SELECT N'DimServicio -> DimServicio',
           (SELECT COUNT(*) FROM BI_GranChimu.dbo.DimServicio), (SELECT COUNT(*) FROM dbo.DimServicio WHERE ServicioKey > 0)
    UNION ALL SELECT N'DimProfesional -> DimProfesional',
           (SELECT COUNT(*) FROM BI_GranChimu.dbo.DimProfesional), (SELECT COUNT(*) FROM dbo.DimProfesional WHERE ProfesionalKey > 0)
    UNION ALL SELECT N'DimTipoAtencion -> DimTipoAtencion',
           (SELECT COUNT(*) FROM BI_GranChimu.dbo.DimTipoAtencion), (SELECT COUNT(*) FROM dbo.DimTipoAtencion WHERE TipoAtencionKey > 0)
    UNION ALL SELECT N'DimEstadoCita -> DimEstadoCita',
           (SELECT COUNT(*) FROM BI_GranChimu.dbo.DimEstadoCita), (SELECT COUNT(*) FROM dbo.DimEstadoCita WHERE EstadoCitaKey > 0)
    UNION ALL SELECT N'DimGrupoEtario -> DimGrupoEtario',
           (SELECT COUNT(*) FROM BI_GranChimu.dbo.DimGrupoEtario), (SELECT COUNT(*) FROM dbo.DimGrupoEtario WHERE GrupoEtarioKey > 0)
    UNION ALL SELECT N'DimDiagnostico -> DimDiagnostico',
           (SELECT COUNT(*) FROM BI_GranChimu.dbo.DimDiagnostico), (SELECT COUNT(*) FROM dbo.DimDiagnostico WHERE DiagnosticoKey > 0)
    UNION ALL SELECT N'Citas (motivos distintos) -> DimMotivoCita',
           (SELECT COUNT(DISTINCT MotivoCita) FROM BI_GranChimu.dbo.Citas), (SELECT COUNT(*) FROM dbo.DimMotivoCita WHERE MotivoCitaKey > 0)
    UNION ALL SELECT N'Atenciones -> FactAtenciones',
           (SELECT COUNT(*) FROM BI_GranChimu.dbo.Atenciones), (SELECT COUNT(*) FROM dbo.FactAtenciones)
    UNION ALL SELECT N'DiagnosticosAtencion -> FactDiagnosticos',
           (SELECT COUNT(*) FROM BI_GranChimu.dbo.DiagnosticosAtencion), (SELECT COUNT(*) FROM dbo.FactDiagnosticos)
    UNION ALL SELECT N'Citas -> FactCitas',
           (SELECT COUNT(*) FROM BI_GranChimu.dbo.Citas), (SELECT COUNT(*) FROM dbo.FactCitas)
) AS x
ORDER BY x.Objeto;
GO

-- 3. REGISTROS RECHAZADOS Y CORREGIDOS. Resultado esperado: 0 rechazados.
SELECT COUNT(*) AS FilasRechazadas FROM etl.FilasRechazadas;
SELECT Tabla, Motivo, COUNT(*) AS Filas FROM etl.FilasRechazadas GROUP BY Tabla, Motivo;
GO

-- 4. INTEGRIDAD: hechos que quedaron con el miembro "No especificado" (clave -1). Esperado: todo en 0.
SELECT N'FactAtenciones' AS Hecho,
       SUM(CASE WHEN PacienteKey = -1 THEN 1 ELSE 0 END) AS SinPaciente,
       SUM(CASE WHEN ServicioKey = -1 THEN 1 ELSE 0 END) AS SinServicio,
       SUM(CASE WHEN ProfesionalKey = -1 THEN 1 ELSE 0 END) AS SinProfesional,
       SUM(CASE WHEN TipoAtencionKey = -1 THEN 1 ELSE 0 END) AS SinTipo,
       SUM(CASE WHEN SectorKey = -1 THEN 1 ELSE 0 END) AS SinSector,
       SUM(CASE WHEN SeguroKey = -1 THEN 1 ELSE 0 END) AS SinSeguro,
       SUM(CASE WHEN GrupoEtarioKey = -1 THEN 1 ELSE 0 END) AS SinGrupoEtario
FROM dbo.FactAtenciones
UNION ALL
SELECT N'FactDiagnosticos',
       SUM(CASE WHEN PacienteKey = -1 THEN 1 ELSE 0 END), SUM(CASE WHEN ServicioKey = -1 THEN 1 ELSE 0 END),
       SUM(CASE WHEN DiagnosticoKey = -1 THEN 1 ELSE 0 END), 0,
       SUM(CASE WHEN SectorKey = -1 THEN 1 ELSE 0 END), 0, SUM(CASE WHEN GrupoEtarioKey = -1 THEN 1 ELSE 0 END)
FROM dbo.FactDiagnosticos
UNION ALL
SELECT N'FactCitas',
       SUM(CASE WHEN PacienteKey = -1 THEN 1 ELSE 0 END), SUM(CASE WHEN ServicioKey = -1 THEN 1 ELSE 0 END),
       SUM(CASE WHEN ProfesionalKey = -1 THEN 1 ELSE 0 END), SUM(CASE WHEN EstadoCitaKey = -1 THEN 1 ELSE 0 END),
       SUM(CASE WHEN SectorKey = -1 THEN 1 ELSE 0 END), SUM(CASE WHEN SeguroKey = -1 THEN 1 ELSE 0 END),
       SUM(CASE WHEN GrupoEtarioKey = -1 THEN 1 ELSE 0 END)
FROM dbo.FactCitas;
GO

-- 5. COHERENCIA DE MEDIDAS ENTRE ORIGEN Y DW. Resultado esperado: Resultado = OK en todas.
SELECT m.Medida, m.ValorOrigen, m.ValorDW,
       CASE WHEN m.ValorOrigen = m.ValorDW THEN N'OK' ELSE N'REVISAR' END AS Resultado
FROM
(
    SELECT N'Atenciones (suma de CantidadAtenciones)' AS Medida,
           (SELECT COUNT(*) FROM BI_GranChimu.dbo.Atenciones) AS ValorOrigen,
           (SELECT SUM(CantidadAtenciones) FROM dbo.FactAtenciones) AS ValorDW
    UNION ALL SELECT N'Minutos de espera (suma)',
           (SELECT SUM(CAST(TiempoEsperaMin AS BIGINT)) FROM BI_GranChimu.dbo.Atenciones),
           (SELECT SUM(CAST(TiempoEsperaMin AS BIGINT)) FROM dbo.FactAtenciones)
    UNION ALL SELECT N'Minutos de duración (suma)',
           (SELECT SUM(CAST(DuracionMin AS BIGINT)) FROM BI_GranChimu.dbo.Atenciones),
           (SELECT SUM(CAST(DuracionMin AS BIGINT)) FROM dbo.FactAtenciones)
    UNION ALL SELECT N'Atenciones con cita',
           (SELECT COUNT(*) FROM BI_GranChimu.dbo.Atenciones WHERE CitaID IS NOT NULL),
           (SELECT SUM(AtencionesConCita) FROM dbo.FactAtenciones)
    UNION ALL SELECT N'Citas asistidas',
           (SELECT COUNT(*) FROM BI_GranChimu.dbo.Citas WHERE EstadoCitaID = 2), (SELECT SUM(Asistidas) FROM dbo.FactCitas)
    UNION ALL SELECT N'Citas no asistidas',
           (SELECT COUNT(*) FROM BI_GranChimu.dbo.Citas WHERE EstadoCitaID = 3), (SELECT SUM(Inasistencias) FROM dbo.FactCitas)
    UNION ALL SELECT N'Citas reprogramadas',
           (SELECT COUNT(*) FROM BI_GranChimu.dbo.Citas WHERE EstadoCitaID = 4), (SELECT SUM(Reprogramadas) FROM dbo.FactCitas)
    UNION ALL SELECT N'Citas canceladas',
           (SELECT COUNT(*) FROM BI_GranChimu.dbo.Citas WHERE EstadoCitaID = 5), (SELECT SUM(Canceladas) FROM dbo.FactCitas)
    UNION ALL SELECT N'Segundas citas',
           (SELECT COUNT(*) FROM BI_GranChimu.dbo.Citas WHERE NumeroCita = 2), (SELECT SUM(EsSegundaCita) FROM dbo.FactCitas)
    UNION ALL SELECT N'Diagnósticos principales',
           (SELECT COUNT(*) FROM BI_GranChimu.dbo.DiagnosticosAtencion WHERE Orden = 1), (SELECT SUM(DiagnosticosPrincipales) FROM dbo.FactDiagnosticos)
    UNION ALL SELECT N'Pacientes con al menos una atención',
           (SELECT COUNT(DISTINCT DNI) FROM BI_GranChimu.dbo.Atenciones), (SELECT COUNT(DISTINCT PacienteKey) FROM dbo.FactAtenciones)
) AS m;
GO

-- 6. UNICIDAD DE CLAVES DE NEGOCIO Y VALORES FUERA DE RANGO. Esperado: ambas consultas sin filas.
SELECT N'CodigoPaciente repetido' AS Problema, CodigoPaciente AS Valor, COUNT(*) AS Veces
FROM dbo.DimPaciente GROUP BY CodigoPaciente HAVING COUNT(*) > 1
UNION ALL
SELECT N'AtencionID_Origen repetido', CAST(AtencionID_Origen AS NVARCHAR(20)), COUNT(*)
FROM dbo.FactAtenciones GROUP BY AtencionID_Origen HAVING COUNT(*) > 1
UNION ALL
SELECT N'CitaID_Origen repetido', CAST(CitaID_Origen AS NVARCHAR(20)), COUNT(*)
FROM dbo.FactCitas GROUP BY CitaID_Origen HAVING COUNT(*) > 1;

SELECT N'Atención en domingo o feriado' AS Problema, COUNT(*) AS Filas
FROM dbo.FactAtenciones AS a JOIN dbo.DimFecha AS f ON f.FechaKey = a.FechaKey WHERE f.EsDiaLaborable = 0
UNION ALL
SELECT N'Atención antes del registro del paciente', COUNT(*)
FROM dbo.FactAtenciones AS a
JOIN dbo.DimFecha AS f ON f.FechaKey = a.FechaKey
JOIN dbo.DimPaciente AS p ON p.PacienteKey = a.PacienteKey WHERE f.Fecha < p.FechaRegistro
UNION ALL
SELECT N'Cita programada antes de su registro', COUNT(*)
FROM dbo.FactCitas AS c
JOIN dbo.DimFecha AS fp ON fp.FechaKey = c.FechaProgramadaKey
JOIN dbo.DimFecha AS fr ON fr.FechaKey = c.FechaRegistroKey WHERE fp.Fecha < fr.Fecha;
GO

-- 7. DATOS PERSONALES: el DW no debe contener DNI, nombres ni teléfono. Esperado: 0 filas.
SELECT TABLE_NAME, COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = N'dbo'
  AND (COLUMN_NAME IN (N'DNI', N'Nombres', N'Apellidos', N'TelefonoContacto'));
GO

-- 8. VISTA PREVIA DE LO QUE VERÁ EL CUBO / POWER BI (sirve para comprobar que el modelo responde preguntas).
-- 8.1 Atenciones por mes y servicio.
SELECT f.AnioMes, s.NombreServicio, COUNT(*) AS Atenciones, AVG(CAST(a.TiempoEsperaMin AS DECIMAL(6,1))) AS EsperaPromedioMin
FROM dbo.FactAtenciones AS a
JOIN dbo.DimFecha AS f ON f.FechaKey = a.FechaKey
JOIN dbo.DimServicio AS s ON s.ServicioKey = a.ServicioKey
GROUP BY f.AnioMes, s.NombreServicio
ORDER BY f.AnioMes, Atenciones DESC;

-- 8.2 Top 10 de morbilidad (diagnóstico principal).
SELECT TOP (10) d.CodigoCIE10, d.Descripcion, COUNT(*) AS Casos
FROM dbo.FactDiagnosticos AS x
JOIN dbo.DimDiagnostico AS d ON d.DiagnosticoKey = x.DiagnosticoKey
WHERE x.DiagnosticosPrincipales = 1
GROUP BY d.CodigoCIE10, d.Descripcion
ORDER BY Casos DESC;

-- 8.3 Asistencia a citas según el recordatorio (solo citas ya resueltas).
SELECT r.NombreMedio,
       COUNT(*) AS CitasCerradas,
       SUM(c.Asistidas) AS Asistidas,
       CAST(100.0 * SUM(c.Inasistencias) / COUNT(*) AS DECIMAL(5,1)) AS PctInasistencia
FROM dbo.FactCitas AS c
JOIN dbo.DimRecordatorio AS r ON r.RecordatorioKey = c.RecordatorioKey
WHERE c.Asistidas = 1 OR c.Inasistencias = 1
GROUP BY r.NombreMedio
ORDER BY PctInasistencia;

-- 8.4 Inasistencia por sector.
SELECT s.NombreSector, COUNT(*) AS Citas, SUM(c.Inasistencias) AS Inasistencias,
       CAST(100.0 * SUM(c.Inasistencias) / NULLIF(SUM(c.Asistidas) + SUM(c.Inasistencias), 0) AS DECIMAL(5,1)) AS PctInasistencia
FROM dbo.FactCitas AS c
JOIN dbo.DimSector AS s ON s.SectorKey = c.SectorKey
GROUP BY s.NombreSector
ORDER BY s.NombreSector;
GO
