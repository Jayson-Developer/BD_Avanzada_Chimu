-- PRÁCTICA DE CAMPO 3 | PUESTO DE SALUD GRAN CHIMÚ (CASO ACADÉMICO)
-- SCRIPT 3: DATA WAREHOUSE (modelo en estrella) | SQL Server 2022
--
-- ARQUITECTURA
--   BI_GranChimu (ORIGEN, scripts 1 y 2)  --[ETL en SSIS]-->  BI_GranChimu_DW (este script)
--        --> SQL Server Analysis Services (cubo)  -->  Power BI
--
-- ESTE SCRIPT SOLO CREA LA ESTRUCTURA. NO INSERTA DATOS DE NEGOCIO:
-- las dimensiones y los hechos los carga el paquete SSIS desde la base de origen.
-- Lo único que inserta son (a) el miembro "No especificado" (clave -1) de las dimensiones,
-- que sirve para no perder hechos cuando una búsqueda de clave falla, y (b) tres catálogos
-- fijos propios del DW: DimTurno, DimTipoDiagnostico y DimRecordatorio.
--
-- DECISIONES DE DISEÑO
--   * Claves sustitutas (INT IDENTITY) en todas las dimensiones; la clave de negocio de origen
--     se guarda en la columna *_Origen (o CodigoPaciente) y sirve para las búsquedas del ETL.
--   * El DW NO guarda DNI, nombres ni teléfono del paciente: el análisis no los necesita.
--   * Estrella pura: Sector y Seguro están en los hechos; DimPaciente solo los repite como
--     texto informativo, sin relación (evita rutas dobles en Analysis Services).
--   * DimFecha es de rol múltiple: FactCitas usa FechaProgramadaKey y FechaRegistroKey.
--   * Carga completa (full load): etl.usp_VaciarDW deja el DW listo para cargar de nuevo.
--
-- Los datos de origen son SINTÉTICOS. Ejecutar DESPUÉS de los scripts 1 y 2.

IF DB_ID(N'BI_GranChimu_DW') IS NULL
BEGIN
    CREATE DATABASE BI_GranChimu_DW;
END;
GO

USE BI_GranChimu_DW;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'etl') IS NULL
    EXEC (N'CREATE SCHEMA etl');
GO

-- 0. REINICIO OPCIONAL (descomentar solo para recrear todo el DW desde cero).
/*
DROP TABLE IF EXISTS dbo.FactDiagnosticos, dbo.FactCitas, dbo.FactAtenciones;
DROP TABLE IF EXISTS dbo.DimPaciente, dbo.DimSector, dbo.DimSeguro, dbo.DimServicio, dbo.DimProfesional,
                     dbo.DimTipoAtencion, dbo.DimEstadoCita, dbo.DimGrupoEtario, dbo.DimDiagnostico,
                     dbo.DimMotivoCita, dbo.DimTurno, dbo.DimTipoDiagnostico, dbo.DimRecordatorio, dbo.DimFecha;
DROP PROCEDURE IF EXISTS etl.usp_VaciarDW, etl.usp_RegistrarCarga;
DROP TABLE IF EXISTS etl.FilasRechazadas, etl.LogCarga;
*/

-- 1. DIMENSIONES.
IF OBJECT_ID(N'dbo.DimFecha', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimFecha
    (
        FechaKey         INT           NOT NULL,   -- AAAAMMDD
        Fecha            DATE          NOT NULL,
        Anio             SMALLINT      NOT NULL,
        Semestre         TINYINT       NOT NULL,
        Trimestre        TINYINT       NOT NULL,
        NombreTrimestre  NVARCHAR(4)   NOT NULL,   -- T1 ... T4
        Mes              TINYINT       NOT NULL,   -- ordena a NombreMes en el cubo
        NombreMes        NVARCHAR(12)  NOT NULL,
        AnioMes          CHAR(7)       NOT NULL,   -- AAAA-MM
        SemanaISO        TINYINT       NOT NULL,
        DiaSemana        TINYINT       NOT NULL,   -- 1 = lunes ... 7 = domingo
        NombreDia        NVARCHAR(12)  NOT NULL,
        EsFinDeSemana    BIT           NOT NULL,
        EsFeriado        BIT           NOT NULL,
        NombreFeriado    NVARCHAR(60)  NULL,
        EsDiaLaborable   BIT           NOT NULL,
        FechaCarga       DATETIME2(0)  NOT NULL CONSTRAINT DF_DimFecha_Carga DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_DimFecha PRIMARY KEY (FechaKey),
        CONSTRAINT UQ_DimFecha_Fecha UNIQUE (Fecha)
    );
END;
GO

IF OBJECT_ID(N'dbo.DimPaciente', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimPaciente
    (
        PacienteKey      INT           IDENTITY(1,1) NOT NULL,
        CodigoPaciente   VARCHAR(7)    NOT NULL,   -- clave de negocio (GC-0001); no se usa el DNI
        Sexo             CHAR(1)       NOT NULL,
        FechaNacimiento  DATE          NOT NULL,
        EdadAlCierre     TINYINT       NOT NULL,   -- al 30/09/2026
        GrupoEtario      NVARCHAR(20)  NOT NULL,
        EtapaVida        NVARCHAR(20)  NOT NULL,
        NombreSector     NVARCHAR(30)  NOT NULL,   -- informativo, sin relación con DimSector
        NombreSeguro     NVARCHAR(30)  NOT NULL,   -- informativo, sin relación con DimSeguro
        FechaRegistro    DATE          NOT NULL,
        AnioMesRegistro  CHAR(7)       NOT NULL,
        FechaCarga       DATETIME2(0)  NOT NULL CONSTRAINT DF_DimPaciente_Carga DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_DimPaciente PRIMARY KEY (PacienteKey),
        CONSTRAINT UQ_DimPaciente_Codigo UNIQUE (CodigoPaciente),
        CONSTRAINT CK_DimPaciente_Sexo CHECK (Sexo IN ('F', 'M', 'N'))
    );
END;
GO

IF OBJECT_ID(N'dbo.DimSector', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimSector
    (
        SectorKey          INT           IDENTITY(1,1) NOT NULL,
        SectorID_Origen    TINYINT       NOT NULL,
        NombreSector       NVARCHAR(30)  NOT NULL,
        ZonaReferencial    NVARCHAR(40)  NOT NULL,
        PoblacionEstimada  INT           NOT NULL,
        Latitud            DECIMAL(9,6)  NULL,
        Longitud           DECIMAL(9,6)  NULL,
        FechaCarga         DATETIME2(0)  NOT NULL CONSTRAINT DF_DimSector_Carga DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_DimSector PRIMARY KEY (SectorKey),
        CONSTRAINT UQ_DimSector_Origen UNIQUE (SectorID_Origen)
    );
END;
GO

IF OBJECT_ID(N'dbo.DimSeguro', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimSeguro
    (
        SeguroKey           INT           IDENTITY(1,1) NOT NULL,
        SeguroID_Origen     TINYINT       NOT NULL,
        NombreSeguro        NVARCHAR(30)  NOT NULL,
        TipoFinanciamiento  NVARCHAR(30)  NOT NULL,
        FechaCarga          DATETIME2(0)  NOT NULL CONSTRAINT DF_DimSeguro_Carga DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_DimSeguro PRIMARY KEY (SeguroKey),
        CONSTRAINT UQ_DimSeguro_Origen UNIQUE (SeguroID_Origen)
    );
END;
GO

IF OBJECT_ID(N'dbo.DimServicio', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimServicio
    (
        ServicioKey        INT           IDENTITY(1,1) NOT NULL,
        ServicioID_Origen  TINYINT       NOT NULL,
        NombreServicio     NVARCHAR(30)  NOT NULL,
        AreaFuncional      NVARCHAR(40)  NOT NULL,
        FechaCarga         DATETIME2(0)  NOT NULL CONSTRAINT DF_DimServicio_Carga DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_DimServicio PRIMARY KEY (ServicioKey),
        CONSTRAINT UQ_DimServicio_Origen UNIQUE (ServicioID_Origen)
    );
END;
GO

IF OBJECT_ID(N'dbo.DimProfesional', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimProfesional
    (
        ProfesionalKey        INT            IDENTITY(1,1) NOT NULL,
        ProfesionalID_Origen  SMALLINT       NOT NULL,
        NombreCompleto        NVARCHAR(100)  NOT NULL,
        Profesion             NVARCHAR(40)   NOT NULL,
        CondicionLaboral      NVARCHAR(20)   NOT NULL,
        NombreServicio        NVARCHAR(30)   NOT NULL,   -- permite la jerarquía Servicio > Profesional
        FechaCarga            DATETIME2(0)   NOT NULL CONSTRAINT DF_DimProfesional_Carga DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_DimProfesional PRIMARY KEY (ProfesionalKey),
        CONSTRAINT UQ_DimProfesional_Origen UNIQUE (ProfesionalID_Origen)
    );
END;
GO

IF OBJECT_ID(N'dbo.DimTipoAtencion', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimTipoAtencion
    (
        TipoAtencionKey        INT           IDENTITY(1,1) NOT NULL,
        TipoAtencionID_Origen  TINYINT       NOT NULL,
        NombreTipo             NVARCHAR(30)  NOT NULL,
        FechaCarga             DATETIME2(0)  NOT NULL CONSTRAINT DF_DimTipoAtencion_Carga DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_DimTipoAtencion PRIMARY KEY (TipoAtencionKey),
        CONSTRAINT UQ_DimTipoAtencion_Origen UNIQUE (TipoAtencionID_Origen)
    );
END;
GO

IF OBJECT_ID(N'dbo.DimEstadoCita', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimEstadoCita
    (
        EstadoCitaKey        INT            IDENTITY(1,1) NOT NULL,
        EstadoCitaID_Origen  TINYINT        NOT NULL,
        NombreEstado         NVARCHAR(20)   NOT NULL,
        Descripcion          NVARCHAR(100)  NOT NULL,
        FechaCarga           DATETIME2(0)   NOT NULL CONSTRAINT DF_DimEstadoCita_Carga DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_DimEstadoCita PRIMARY KEY (EstadoCitaKey),
        CONSTRAINT UQ_DimEstadoCita_Origen UNIQUE (EstadoCitaID_Origen)
    );
END;
GO

IF OBJECT_ID(N'dbo.DimGrupoEtario', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimGrupoEtario
    (
        GrupoEtarioKey        INT           IDENTITY(1,1) NOT NULL,
        GrupoEtarioID_Origen  TINYINT       NOT NULL,
        NombreGrupo           NVARCHAR(20)  NOT NULL,
        EdadMinima            TINYINT       NOT NULL,
        EdadMaxima            TINYINT       NOT NULL,
        EtapaVida             NVARCHAR(20)  NOT NULL,
        FechaCarga            DATETIME2(0)  NOT NULL CONSTRAINT DF_DimGrupoEtario_Carga DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_DimGrupoEtario PRIMARY KEY (GrupoEtarioKey),
        CONSTRAINT UQ_DimGrupoEtario_Origen UNIQUE (GrupoEtarioID_Origen)
    );
END;
GO

IF OBJECT_ID(N'dbo.DimDiagnostico', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimDiagnostico
    (
        DiagnosticoKey        INT            IDENTITY(1,1) NOT NULL,
        DiagnosticoID_Origen  SMALLINT       NOT NULL,
        CodigoCIE10           VARCHAR(8)     NOT NULL,
        Descripcion           NVARCHAR(150)  NOT NULL,
        Etiqueta              NVARCHAR(170)  NOT NULL,   -- "J06.9 - Infección aguda..." para los gráficos
        CapituloCIE10         NVARCHAR(120)  NOT NULL,
        GrupoClinico          NVARCHAR(60)   NOT NULL,
        EsCronico             BIT            NOT NULL,
        FechaCarga            DATETIME2(0)   NOT NULL CONSTRAINT DF_DimDiagnostico_Carga DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_DimDiagnostico PRIMARY KEY (DiagnosticoKey),
        CONSTRAINT UQ_DimDiagnostico_Origen UNIQUE (DiagnosticoID_Origen)
    );
END;
GO

IF OBJECT_ID(N'dbo.DimMotivoCita', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimMotivoCita
    (
        MotivoCitaKey  INT           IDENTITY(1,1) NOT NULL,
        NombreMotivo   NVARCHAR(40)  NOT NULL,   -- se carga con los motivos distintos de Citas
        FechaCarga     DATETIME2(0)  NOT NULL CONSTRAINT DF_DimMotivoCita_Carga DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_DimMotivoCita PRIMARY KEY (MotivoCitaKey),
        CONSTRAINT UQ_DimMotivoCita_Nombre UNIQUE (NombreMotivo)
    );
END;
GO

-- Catálogos fijos propios del DW (no vienen del origen).
IF OBJECT_ID(N'dbo.DimTurno', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimTurno
    (
        TurnoKey      TINYINT       NOT NULL,
        NombreTurno   NVARCHAR(10)  NOT NULL,
        CONSTRAINT PK_DimTurno PRIMARY KEY (TurnoKey),
        CONSTRAINT UQ_DimTurno_Nombre UNIQUE (NombreTurno)
    );
END;
GO

IF OBJECT_ID(N'dbo.DimTipoDiagnostico', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimTipoDiagnostico
    (
        TipoDxKey     TINYINT       NOT NULL,
        CodigoTipo    CHAR(1)       NOT NULL,   -- P / D / R, como llega del origen
        NombreTipo    NVARCHAR(20)  NOT NULL,
        CONSTRAINT PK_DimTipoDiagnostico PRIMARY KEY (TipoDxKey),
        CONSTRAINT UQ_DimTipoDiagnostico_Codigo UNIQUE (CodigoTipo)
    );
END;
GO

IF OBJECT_ID(N'dbo.DimRecordatorio', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimRecordatorio
    (
        RecordatorioKey      TINYINT       NOT NULL,
        NombreMedio          NVARCHAR(20)  NOT NULL,   -- Sin recordatorio / Llamada / WhatsApp / SMS
        SeEnvioRecordatorio  BIT           NOT NULL,
        CONSTRAINT PK_DimRecordatorio PRIMARY KEY (RecordatorioKey),
        CONSTRAINT UQ_DimRecordatorio_Medio UNIQUE (NombreMedio)
    );
END;
GO

-- 2. TABLAS DE HECHOS.
-- Hecho 1. Grano: una fila por atención.
IF OBJECT_ID(N'dbo.FactAtenciones', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.FactAtenciones
    (
        AtencionKey         INT          IDENTITY(1,1) NOT NULL,
        AtencionID_Origen   INT          NOT NULL,
        FechaKey            INT          NOT NULL,
        PacienteKey         INT          NOT NULL,
        ServicioKey         INT          NOT NULL,
        ProfesionalKey      INT          NOT NULL,
        TipoAtencionKey     INT          NOT NULL,
        SectorKey           INT          NOT NULL,
        SeguroKey           INT          NOT NULL,
        GrupoEtarioKey      INT          NOT NULL,   -- edad a la fecha de la atención
        TurnoKey            TINYINT      NOT NULL,
        HoraInicio          TIME(0)      NOT NULL,
        EdadAlAtender       TINYINT      NOT NULL,
        CantidadAtenciones  INT          NOT NULL CONSTRAINT DF_FactAtenciones_Cant DEFAULT (1),
        AtencionesConCita   INT          NOT NULL,   -- 1 si llegó con cita, 0 si no
        TiempoEsperaMin     SMALLINT     NOT NULL,
        DuracionMin         SMALLINT     NOT NULL,
        FechaCarga          DATETIME2(0) NOT NULL CONSTRAINT DF_FactAtenciones_Carga DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_FactAtenciones PRIMARY KEY (AtencionKey),
        CONSTRAINT UQ_FactAtenciones_Origen UNIQUE (AtencionID_Origen),
        CONSTRAINT FK_FactAtenciones_Fecha        FOREIGN KEY (FechaKey)        REFERENCES dbo.DimFecha (FechaKey),
        CONSTRAINT FK_FactAtenciones_Paciente     FOREIGN KEY (PacienteKey)     REFERENCES dbo.DimPaciente (PacienteKey),
        CONSTRAINT FK_FactAtenciones_Servicio     FOREIGN KEY (ServicioKey)     REFERENCES dbo.DimServicio (ServicioKey),
        CONSTRAINT FK_FactAtenciones_Profesional  FOREIGN KEY (ProfesionalKey)  REFERENCES dbo.DimProfesional (ProfesionalKey),
        CONSTRAINT FK_FactAtenciones_Tipo         FOREIGN KEY (TipoAtencionKey) REFERENCES dbo.DimTipoAtencion (TipoAtencionKey),
        CONSTRAINT FK_FactAtenciones_Sector       FOREIGN KEY (SectorKey)       REFERENCES dbo.DimSector (SectorKey),
        CONSTRAINT FK_FactAtenciones_Seguro       FOREIGN KEY (SeguroKey)       REFERENCES dbo.DimSeguro (SeguroKey),
        CONSTRAINT FK_FactAtenciones_GrupoEtario  FOREIGN KEY (GrupoEtarioKey)  REFERENCES dbo.DimGrupoEtario (GrupoEtarioKey),
        CONSTRAINT FK_FactAtenciones_Turno        FOREIGN KEY (TurnoKey)        REFERENCES dbo.DimTurno (TurnoKey),
        CONSTRAINT CK_FactAtenciones_Espera   CHECK (TiempoEsperaMin >= 0),
        CONSTRAINT CK_FactAtenciones_Duracion CHECK (DuracionMin > 0),
        CONSTRAINT CK_FactAtenciones_ConCita  CHECK (AtencionesConCita IN (0, 1))
    );
END;
GO

-- Hecho 2. Grano: una fila por diagnóstico registrado en una atención.
IF OBJECT_ID(N'dbo.FactDiagnosticos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.FactDiagnosticos
    (
        DiagnosticoFactKey       INT          IDENTITY(1,1) NOT NULL,
        AtencionKey              INT          NOT NULL,
        Orden                    TINYINT      NOT NULL,   -- 1 = principal
        FechaKey                 INT          NOT NULL,
        PacienteKey              INT          NOT NULL,
        ServicioKey              INT          NOT NULL,
        DiagnosticoKey           INT          NOT NULL,
        TipoDxKey                TINYINT      NOT NULL,
        GrupoEtarioKey           INT          NOT NULL,
        SectorKey                INT          NOT NULL,
        CantidadDiagnosticos     INT          NOT NULL CONSTRAINT DF_FactDiagnosticos_Cant DEFAULT (1),
        DiagnosticosPrincipales  INT          NOT NULL,   -- 1 si Orden = 1
        FechaCarga               DATETIME2(0) NOT NULL CONSTRAINT DF_FactDiagnosticos_Carga DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_FactDiagnosticos PRIMARY KEY (DiagnosticoFactKey),
        CONSTRAINT UQ_FactDiagnosticos_Atencion_Orden UNIQUE (AtencionKey, Orden),
        CONSTRAINT FK_FactDiagnosticos_Atencion     FOREIGN KEY (AtencionKey)    REFERENCES dbo.FactAtenciones (AtencionKey),
        CONSTRAINT FK_FactDiagnosticos_Fecha        FOREIGN KEY (FechaKey)       REFERENCES dbo.DimFecha (FechaKey),
        CONSTRAINT FK_FactDiagnosticos_Paciente     FOREIGN KEY (PacienteKey)    REFERENCES dbo.DimPaciente (PacienteKey),
        CONSTRAINT FK_FactDiagnosticos_Servicio     FOREIGN KEY (ServicioKey)    REFERENCES dbo.DimServicio (ServicioKey),
        CONSTRAINT FK_FactDiagnosticos_Diagnostico  FOREIGN KEY (DiagnosticoKey) REFERENCES dbo.DimDiagnostico (DiagnosticoKey),
        CONSTRAINT FK_FactDiagnosticos_TipoDx       FOREIGN KEY (TipoDxKey)      REFERENCES dbo.DimTipoDiagnostico (TipoDxKey),
        CONSTRAINT FK_FactDiagnosticos_GrupoEtario  FOREIGN KEY (GrupoEtarioKey) REFERENCES dbo.DimGrupoEtario (GrupoEtarioKey),
        CONSTRAINT FK_FactDiagnosticos_Sector       FOREIGN KEY (SectorKey)      REFERENCES dbo.DimSector (SectorKey),
        CONSTRAINT CK_FactDiagnosticos_Principal CHECK (DiagnosticosPrincipales IN (0, 1))
    );
END;
GO

-- Hecho 3. Grano: una fila por cita (incluye las reprogramadas y las no asistidas).
IF OBJECT_ID(N'dbo.FactCitas', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.FactCitas
    (
        CitaKey                INT          IDENTITY(1,1) NOT NULL,
        CitaID_Origen          INT          NOT NULL,
        FechaProgramadaKey     INT          NOT NULL,   -- rol: fecha para la que se agendó
        FechaRegistroKey       INT          NOT NULL,   -- rol: fecha en que se agendó
        PacienteKey            INT          NOT NULL,
        ServicioKey            INT          NOT NULL,
        ProfesionalKey         INT          NOT NULL,
        EstadoCitaKey          INT          NOT NULL,
        MotivoCitaKey          INT          NOT NULL,
        RecordatorioKey        TINYINT      NOT NULL,
        SectorKey              INT          NOT NULL,
        SeguroKey              INT          NOT NULL,
        GrupoEtarioKey         INT          NOT NULL,   -- edad a la fecha programada
        NumeroCita             TINYINT      NOT NULL,   -- 2 = segunda cita (primer seguimiento)
        CitaAnteriorID_Origen  INT          NULL,
        CantidadCitas          INT          NOT NULL CONSTRAINT DF_FactCitas_Cant DEFAULT (1),
        Asistidas              INT          NOT NULL,
        Inasistencias          INT          NOT NULL,
        Reprogramadas          INT          NOT NULL,
        Canceladas             INT          NOT NULL,
        EsSegundaCita          INT          NOT NULL,
        DiasAnticipacion       INT          NOT NULL,
        FechaCarga             DATETIME2(0) NOT NULL CONSTRAINT DF_FactCitas_Carga DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_FactCitas PRIMARY KEY (CitaKey),
        CONSTRAINT UQ_FactCitas_Origen UNIQUE (CitaID_Origen),
        CONSTRAINT FK_FactCitas_FechaProg     FOREIGN KEY (FechaProgramadaKey) REFERENCES dbo.DimFecha (FechaKey),
        CONSTRAINT FK_FactCitas_FechaReg      FOREIGN KEY (FechaRegistroKey)   REFERENCES dbo.DimFecha (FechaKey),
        CONSTRAINT FK_FactCitas_Paciente      FOREIGN KEY (PacienteKey)        REFERENCES dbo.DimPaciente (PacienteKey),
        CONSTRAINT FK_FactCitas_Servicio      FOREIGN KEY (ServicioKey)        REFERENCES dbo.DimServicio (ServicioKey),
        CONSTRAINT FK_FactCitas_Profesional   FOREIGN KEY (ProfesionalKey)     REFERENCES dbo.DimProfesional (ProfesionalKey),
        CONSTRAINT FK_FactCitas_Estado        FOREIGN KEY (EstadoCitaKey)      REFERENCES dbo.DimEstadoCita (EstadoCitaKey),
        CONSTRAINT FK_FactCitas_Motivo        FOREIGN KEY (MotivoCitaKey)      REFERENCES dbo.DimMotivoCita (MotivoCitaKey),
        CONSTRAINT FK_FactCitas_Recordatorio  FOREIGN KEY (RecordatorioKey)    REFERENCES dbo.DimRecordatorio (RecordatorioKey),
        CONSTRAINT FK_FactCitas_Sector        FOREIGN KEY (SectorKey)          REFERENCES dbo.DimSector (SectorKey),
        CONSTRAINT FK_FactCitas_Seguro        FOREIGN KEY (SeguroKey)          REFERENCES dbo.DimSeguro (SeguroKey),
        CONSTRAINT FK_FactCitas_GrupoEtario   FOREIGN KEY (GrupoEtarioKey)     REFERENCES dbo.DimGrupoEtario (GrupoEtarioKey),
        CONSTRAINT CK_FactCitas_Banderas CHECK (Asistidas IN (0,1) AND Inasistencias IN (0,1) AND Reprogramadas IN (0,1)
                                                AND Canceladas IN (0,1) AND EsSegundaCita IN (0,1)),
        CONSTRAINT CK_FactCitas_UnEstado CHECK (Asistidas + Inasistencias + Reprogramadas + Canceladas <= 1),
        CONSTRAINT CK_FactCitas_Anticipacion CHECK (DiasAnticipacion >= 0)
    );
END;
GO

-- Índices en las claves de los hechos usadas para filtrar y relacionar.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_FactAtenciones_Fecha' AND object_id = OBJECT_ID(N'dbo.FactAtenciones'))
    CREATE INDEX IX_FactAtenciones_Fecha ON dbo.FactAtenciones (FechaKey, ServicioKey);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_FactAtenciones_Paciente' AND object_id = OBJECT_ID(N'dbo.FactAtenciones'))
    CREATE INDEX IX_FactAtenciones_Paciente ON dbo.FactAtenciones (PacienteKey);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_FactDiagnosticos_Dx' AND object_id = OBJECT_ID(N'dbo.FactDiagnosticos'))
    CREATE INDEX IX_FactDiagnosticos_Dx ON dbo.FactDiagnosticos (DiagnosticoKey, FechaKey);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_FactCitas_Fecha' AND object_id = OBJECT_ID(N'dbo.FactCitas'))
    CREATE INDEX IX_FactCitas_Fecha ON dbo.FactCitas (FechaProgramadaKey, EstadoCitaKey);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_FactCitas_Paciente' AND object_id = OBJECT_ID(N'dbo.FactCitas'))
    CREATE INDEX IX_FactCitas_Paciente ON dbo.FactCitas (PacienteKey, NumeroCita);
GO

-- 3. CATÁLOGOS FIJOS DEL DW.
INSERT INTO dbo.DimTurno (TurnoKey, NombreTurno)
SELECT v.TurnoKey, v.NombreTurno
FROM (VALUES (1, N'Mañana'), (2, N'Tarde')) AS v(TurnoKey, NombreTurno)
WHERE NOT EXISTS (SELECT 1 FROM dbo.DimTurno AS t WHERE t.TurnoKey = v.TurnoKey);

INSERT INTO dbo.DimTipoDiagnostico (TipoDxKey, CodigoTipo, NombreTipo)
SELECT v.TipoDxKey, v.CodigoTipo, v.NombreTipo
FROM (VALUES (1, 'P', N'Presuntivo'), (2, 'D', N'Definitivo'), (3, 'R', N'Repetido')) AS v(TipoDxKey, CodigoTipo, NombreTipo)
WHERE NOT EXISTS (SELECT 1 FROM dbo.DimTipoDiagnostico AS t WHERE t.TipoDxKey = v.TipoDxKey);

INSERT INTO dbo.DimRecordatorio (RecordatorioKey, NombreMedio, SeEnvioRecordatorio)
SELECT v.RecordatorioKey, v.NombreMedio, v.SeEnvioRecordatorio
FROM (VALUES (1, N'Sin recordatorio', 0), (2, N'Llamada', 1), (3, N'WhatsApp', 1), (4, N'SMS', 1))
     AS v(RecordatorioKey, NombreMedio, SeEnvioRecordatorio)
WHERE NOT EXISTS (SELECT 1 FROM dbo.DimRecordatorio AS t WHERE t.RecordatorioKey = v.RecordatorioKey);
GO

-- 4. MIEMBRO "NO ESPECIFICADO" (clave -1). El ETL asigna esta clave si una búsqueda no encuentra coincidencia.

IF NOT EXISTS (SELECT 1 FROM dbo.DimPaciente WHERE PacienteKey = -1)
BEGIN
    SET IDENTITY_INSERT dbo.DimPaciente ON;
    INSERT INTO dbo.DimPaciente (PacienteKey, CodigoPaciente, Sexo, FechaNacimiento, EdadAlCierre, GrupoEtario, EtapaVida, NombreSector, NombreSeguro, FechaRegistro, AnioMesRegistro)
    VALUES (-1, 'GC-0000', 'N', '19000101', 0, N'No especificado', N'No especificado', N'No especificado', N'No especificado', '19000101', '1900-01');
    SET IDENTITY_INSERT dbo.DimPaciente OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.DimSector WHERE SectorKey = -1)
BEGIN
    SET IDENTITY_INSERT dbo.DimSector ON;
    INSERT INTO dbo.DimSector (SectorKey, SectorID_Origen, NombreSector, ZonaReferencial, PoblacionEstimada)
    VALUES (-1, 0, N'No especificado', N'No especificado', 0);
    SET IDENTITY_INSERT dbo.DimSector OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.DimSeguro WHERE SeguroKey = -1)
BEGIN
    SET IDENTITY_INSERT dbo.DimSeguro ON;
    INSERT INTO dbo.DimSeguro (SeguroKey, SeguroID_Origen, NombreSeguro, TipoFinanciamiento)
    VALUES (-1, 0, N'No especificado', N'No especificado');
    SET IDENTITY_INSERT dbo.DimSeguro OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.DimServicio WHERE ServicioKey = -1)
BEGIN
    SET IDENTITY_INSERT dbo.DimServicio ON;
    INSERT INTO dbo.DimServicio (ServicioKey, ServicioID_Origen, NombreServicio, AreaFuncional)
    VALUES (-1, 0, N'No especificado', N'No especificado');
    SET IDENTITY_INSERT dbo.DimServicio OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.DimProfesional WHERE ProfesionalKey = -1)
BEGIN
    SET IDENTITY_INSERT dbo.DimProfesional ON;
    INSERT INTO dbo.DimProfesional (ProfesionalKey, ProfesionalID_Origen, NombreCompleto, Profesion, CondicionLaboral, NombreServicio)
    VALUES (-1, 0, N'No especificado', N'No especificado', N'No especificado', N'No especificado');
    SET IDENTITY_INSERT dbo.DimProfesional OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.DimTipoAtencion WHERE TipoAtencionKey = -1)
BEGIN
    SET IDENTITY_INSERT dbo.DimTipoAtencion ON;
    INSERT INTO dbo.DimTipoAtencion (TipoAtencionKey, TipoAtencionID_Origen, NombreTipo)
    VALUES (-1, 0, N'No especificado');
    SET IDENTITY_INSERT dbo.DimTipoAtencion OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.DimEstadoCita WHERE EstadoCitaKey = -1)
BEGIN
    SET IDENTITY_INSERT dbo.DimEstadoCita ON;
    INSERT INTO dbo.DimEstadoCita (EstadoCitaKey, EstadoCitaID_Origen, NombreEstado, Descripcion)
    VALUES (-1, 0, N'No especificado', N'No especificado');
    SET IDENTITY_INSERT dbo.DimEstadoCita OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.DimGrupoEtario WHERE GrupoEtarioKey = -1)
BEGIN
    SET IDENTITY_INSERT dbo.DimGrupoEtario ON;
    INSERT INTO dbo.DimGrupoEtario (GrupoEtarioKey, GrupoEtarioID_Origen, NombreGrupo, EdadMinima, EdadMaxima, EtapaVida)
    VALUES (-1, 0, N'No especificado', 0, 0, N'No especificado');
    SET IDENTITY_INSERT dbo.DimGrupoEtario OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.DimDiagnostico WHERE DiagnosticoKey = -1)
BEGIN
    SET IDENTITY_INSERT dbo.DimDiagnostico ON;
    INSERT INTO dbo.DimDiagnostico (DiagnosticoKey, DiagnosticoID_Origen, CodigoCIE10, Descripcion, Etiqueta, CapituloCIE10, GrupoClinico, EsCronico)
    VALUES (-1, 0, 'SIN-DATO', N'No especificado', N'No especificado', N'No especificado', N'No especificado', 0);
    SET IDENTITY_INSERT dbo.DimDiagnostico OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.DimMotivoCita WHERE MotivoCitaKey = -1)
BEGIN
    SET IDENTITY_INSERT dbo.DimMotivoCita ON;
    INSERT INTO dbo.DimMotivoCita (MotivoCitaKey, NombreMotivo)
    VALUES (-1, N'No especificado');
    SET IDENTITY_INSERT dbo.DimMotivoCita OFF;
END;
GO

-- 5. OBJETOS DE APOYO AL ETL (esquema etl).
IF OBJECT_ID(N'etl.LogCarga', N'U') IS NULL
BEGIN
    CREATE TABLE etl.LogCarga
    (
        LogID            INT           IDENTITY(1,1) NOT NULL,
        Proceso          NVARCHAR(60)  NOT NULL,   -- ej. Carga DimPaciente
        FechaEjecucion   DATETIME2(0)  NOT NULL CONSTRAINT DF_LogCarga_Fecha DEFAULT (SYSDATETIME()),
        FilasLeidas      INT           NULL,
        FilasInsertadas  INT           NULL,
        FilasRechazadas  INT           NULL,
        Estado           NVARCHAR(15)  NOT NULL CONSTRAINT DF_LogCarga_Estado DEFAULT (N'OK'),
        Mensaje          NVARCHAR(400) NULL,
        Usuario          SYSNAME       NOT NULL CONSTRAINT DF_LogCarga_Usuario DEFAULT (SUSER_SNAME()),
        CONSTRAINT PK_LogCarga PRIMARY KEY (LogID),
        CONSTRAINT CK_LogCarga_Estado CHECK (Estado IN (N'OK', N'ERROR', N'ADVERTENCIA'))
    );
END;
GO

IF OBJECT_ID(N'etl.FilasRechazadas', N'U') IS NULL
BEGIN
    CREATE TABLE etl.FilasRechazadas
    (
        RechazoID       INT           IDENTITY(1,1) NOT NULL,
        Tabla           NVARCHAR(60)  NOT NULL,   -- tabla de destino
        ClaveOrigen     NVARCHAR(60)  NULL,       -- clave de la fila en el origen
        Motivo          NVARCHAR(200) NOT NULL,   -- ej. Paciente no encontrado
        FechaRegistro   DATETIME2(0)  NOT NULL CONSTRAINT DF_FilasRechazadas_Fecha DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_FilasRechazadas PRIMARY KEY (RechazoID)
    );
END;
GO

-- Registra una línea del log. Se llama desde una tarea "Ejecutar SQL" al terminar cada flujo de datos.
CREATE OR ALTER PROCEDURE etl.usp_RegistrarCarga
    @Proceso          NVARCHAR(60),
    @FilasLeidas      INT = NULL,
    @FilasInsertadas  INT = NULL,
    @FilasRechazadas  INT = NULL,
    @Estado           NVARCHAR(15) = N'OK',
    @Mensaje          NVARCHAR(400) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO etl.LogCarga (Proceso, FilasLeidas, FilasInsertadas, FilasRechazadas, Estado, Mensaje)
    VALUES (@Proceso, @FilasLeidas, @FilasInsertadas, @FilasRechazadas, @Estado, @Mensaje);
END;
GO

-- Deja el DW sin datos de negocio para volver a ejecutar el paquete SSIS (primera tarea del flujo de control).
-- Los hechos se vacían con DELETE (no TRUNCATE) porque tienen claves foráneas.
-- Los hechos siempre se reinician en 1; las dimensiones solo si ya tenían filas cargadas.
CREATE OR ALTER PROCEDURE etl.usp_VaciarDW
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM dbo.FactDiagnosticos;
    DELETE FROM dbo.FactCitas;
    DELETE FROM dbo.FactAtenciones;
    DBCC CHECKIDENT (N'dbo.FactDiagnosticos', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT (N'dbo.FactCitas', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT (N'dbo.FactAtenciones', RESEED, 0) WITH NO_INFOMSGS;

    -- Dimensiones: se conserva el miembro "No especificado" (clave -1).
    IF EXISTS (SELECT 1 FROM dbo.DimPaciente WHERE PacienteKey > 0)
    BEGIN
        DELETE FROM dbo.DimPaciente WHERE PacienteKey > 0;
        DBCC CHECKIDENT (N'dbo.DimPaciente', RESEED, 0) WITH NO_INFOMSGS;
    END;
    IF EXISTS (SELECT 1 FROM dbo.DimSector WHERE SectorKey > 0)
    BEGIN
        DELETE FROM dbo.DimSector WHERE SectorKey > 0;
        DBCC CHECKIDENT (N'dbo.DimSector', RESEED, 0) WITH NO_INFOMSGS;
    END;
    IF EXISTS (SELECT 1 FROM dbo.DimSeguro WHERE SeguroKey > 0)
    BEGIN
        DELETE FROM dbo.DimSeguro WHERE SeguroKey > 0;
        DBCC CHECKIDENT (N'dbo.DimSeguro', RESEED, 0) WITH NO_INFOMSGS;
    END;
    IF EXISTS (SELECT 1 FROM dbo.DimServicio WHERE ServicioKey > 0)
    BEGIN
        DELETE FROM dbo.DimServicio WHERE ServicioKey > 0;
        DBCC CHECKIDENT (N'dbo.DimServicio', RESEED, 0) WITH NO_INFOMSGS;
    END;
    IF EXISTS (SELECT 1 FROM dbo.DimProfesional WHERE ProfesionalKey > 0)
    BEGIN
        DELETE FROM dbo.DimProfesional WHERE ProfesionalKey > 0;
        DBCC CHECKIDENT (N'dbo.DimProfesional', RESEED, 0) WITH NO_INFOMSGS;
    END;
    IF EXISTS (SELECT 1 FROM dbo.DimTipoAtencion WHERE TipoAtencionKey > 0)
    BEGIN
        DELETE FROM dbo.DimTipoAtencion WHERE TipoAtencionKey > 0;
        DBCC CHECKIDENT (N'dbo.DimTipoAtencion', RESEED, 0) WITH NO_INFOMSGS;
    END;
    IF EXISTS (SELECT 1 FROM dbo.DimEstadoCita WHERE EstadoCitaKey > 0)
    BEGIN
        DELETE FROM dbo.DimEstadoCita WHERE EstadoCitaKey > 0;
        DBCC CHECKIDENT (N'dbo.DimEstadoCita', RESEED, 0) WITH NO_INFOMSGS;
    END;
    IF EXISTS (SELECT 1 FROM dbo.DimGrupoEtario WHERE GrupoEtarioKey > 0)
    BEGIN
        DELETE FROM dbo.DimGrupoEtario WHERE GrupoEtarioKey > 0;
        DBCC CHECKIDENT (N'dbo.DimGrupoEtario', RESEED, 0) WITH NO_INFOMSGS;
    END;
    IF EXISTS (SELECT 1 FROM dbo.DimDiagnostico WHERE DiagnosticoKey > 0)
    BEGIN
        DELETE FROM dbo.DimDiagnostico WHERE DiagnosticoKey > 0;
        DBCC CHECKIDENT (N'dbo.DimDiagnostico', RESEED, 0) WITH NO_INFOMSGS;
    END;
    IF EXISTS (SELECT 1 FROM dbo.DimMotivoCita WHERE MotivoCitaKey > 0)
    BEGIN
        DELETE FROM dbo.DimMotivoCita WHERE MotivoCitaKey > 0;
        DBCC CHECKIDENT (N'dbo.DimMotivoCita', RESEED, 0) WITH NO_INFOMSGS;
    END;
    DELETE FROM dbo.DimFecha;
END;
GO

-- 6. VERIFICACIÓN DE LA ESTRUCTURA (todas deben existir; las dimensiones quedan con 1 fila: la de clave -1).
SELECT t.name AS Tabla, SUM(CASE WHEN i.index_id IN (0, 1) THEN p.rows ELSE 0 END) AS Filas
FROM sys.tables AS t
JOIN sys.partitions AS p ON p.object_id = t.object_id
JOIN sys.indexes AS i ON i.object_id = t.object_id AND i.index_id = p.index_id
WHERE t.schema_id IN (SCHEMA_ID(N'dbo'), SCHEMA_ID(N'etl'))
GROUP BY t.name
ORDER BY CASE WHEN t.name LIKE 'Fact%' THEN 2 WHEN t.name LIKE 'Dim%' THEN 1 ELSE 3 END, t.name;
GO
