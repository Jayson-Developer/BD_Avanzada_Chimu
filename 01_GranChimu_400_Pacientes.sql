-- PRÁCTICA DE CAMPO 3 | PUESTO DE SALUD GRAN CHIMÚ (CASO ACADÉMICO)
-- SQL Server 2022 | 400 pacientes SINTÉTICOS | abril-septiembre de 2026.
-- CAMBIO SOLICITADO: DNI CHAR(8) ES LA CLAVE PRIMARIA de dbo.Pacientes.
-- DNI de ejemplo: 99000001 ... 99000400 (inventados, NO validados por RENIEC).
-- Nombres y datos inventados, únicamente para el proyecto académico.
-- Se conserva CodigoPaciente como identificador auxiliar UNIQUE.
-- Se incluye TelefonoContacto CHAR(9) (paciente o adulto responsable).
-- Teléfonos 900000001 a 900000400: ejemplos sintéticos, NO aptos para contacto real.
-- IMPORTANTE: este script permite partir de cero O adaptar la tabla del archivo
-- anterior (que tenía PacienteID como clave primaria). NO borra pacientes.

IF DB_ID(N'BI_GranChimu') IS NULL
BEGIN
    CREATE DATABASE BI_GranChimu;
END;
GO

USE BI_GranChimu;
GO

-- 1. TABLA NUEVA: DNI es la clave primaria, NO PacienteID.
IF OBJECT_ID(N'dbo.Pacientes', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Pacientes
    (
        DNI               CHAR(8) NOT NULL,
        CodigoPaciente    VARCHAR(7) NOT NULL,
        TelefonoContacto  CHAR(9) NULL,
        Nombres           NVARCHAR(90) NOT NULL,
        Apellidos         NVARCHAR(100) NOT NULL,
        FechaNacimiento   DATE NOT NULL,
        Sexo              CHAR(1) NOT NULL,
        SectorResidencia  NVARCHAR(30) NOT NULL,
        TipoSeguro        NVARCHAR(30) NOT NULL,
        FechaRegistro     DATE NOT NULL,
        CONSTRAINT PK_Pacientes PRIMARY KEY (DNI),
        CONSTRAINT UQ_Pacientes_Codigo UNIQUE (CodigoPaciente),
        CONSTRAINT CK_Pacientes_DNI CHECK (DNI NOT LIKE '%[^0-9]%'),
        CONSTRAINT CK_Pacientes_Sexo CHECK (Sexo IN ('F', 'M')),
        CONSTRAINT CK_Pacientes_Fechas CHECK (FechaNacimiento <= FechaRegistro),
        CONSTRAINT CK_Pacientes_Seguro CHECK (TipoSeguro IN
            (N'SIS', N'EsSalud', N'Sin seguro', N'Otro'))
    );
END;
GO

-- 2. COMPATIBILIDAD CON EL ARCHIVO ANTERIOR.
-- Si ya ejecutaste la versión donde PacienteID era la PK, conserva las filas,
-- incorpora el DNI sintético y lo convierte en la nueva clave primaria.
-- Se realiza SOLO si aún no existe la columna DNI.
IF COL_LENGTH(N'dbo.Pacientes', N'DNI') IS NULL
BEGIN
    IF EXISTS (
        SELECT 1 FROM dbo.Pacientes
        WHERE CodigoPaciente NOT LIKE 'GC-[0-9][0-9][0-9][0-9]'
    )
        THROW 50001, 'Hay codigos distintos del formato GC-0001; revisar antes de migrar.', 1;

    -- La vista vieja referencia PacienteID; se reconstruye al final.
    IF OBJECT_ID(N'dbo.vw_PacientesBI', N'V') IS NOT NULL
        DROP VIEW dbo.vw_PacientesBI;

    ALTER TABLE dbo.Pacientes ADD DNI CHAR(8) NULL;

    UPDATE dbo.Pacientes
       SET DNI = '99' + RIGHT('000000' + SUBSTRING(CodigoPaciente, 4, 4), 6);

    IF EXISTS (SELECT 1 FROM dbo.Pacientes WHERE DNI IS NULL)
        THROW 50002, 'No se pudo asignar DNI a todos los pacientes.', 1;

    ALTER TABLE dbo.Pacientes ALTER COLUMN DNI CHAR(8) NOT NULL;
    ALTER TABLE dbo.Pacientes DROP CONSTRAINT PK_Pacientes;

    -- Eliminamos el antiguo identificador para evitar dos claves aparentes.
    IF COL_LENGTH(N'dbo.Pacientes', N'PacienteID') IS NOT NULL
        ALTER TABLE dbo.Pacientes DROP COLUMN PacienteID;

    ALTER TABLE dbo.Pacientes ADD CONSTRAINT PK_Pacientes PRIMARY KEY (DNI);
    ALTER TABLE dbo.Pacientes ADD CONSTRAINT CK_Pacientes_DNI
        CHECK (DNI NOT LIKE '%[^0-9]%');
END;
GO

-- 3. INSERTAR LOS 400 PACIENTES DE EJEMPLO.
-- Re-ejecutar el script no duplica a quienes ya existen.
-- Lote 1 de 4: pacientes 0001-0100
INSERT INTO dbo.Pacientes
    (DNI, CodigoPaciente, Nombres, Apellidos, FechaNacimiento, Sexo,
     SectorResidencia, TipoSeguro, FechaRegistro)
SELECT v.DNI, v.CodigoPaciente, v.Nombres, v.Apellidos, v.FechaNacimiento,
       v.Sexo, v.SectorResidencia, v.TipoSeguro, v.FechaRegistro
FROM (VALUES
    ('99000001', 'GC-0001', N'Ricardo Paolo', N'López Vásquez', '19611218', 'M', N'Sector 04', N'Sin seguro', '20260709'),
    ('99000002', 'GC-0002', N'Ana Lucía', N'Salazar Ortega', '19941129', 'F', N'Sector 03', N'SIS', '20260918'),
    ('99000003', 'GC-0003', N'María Fernanda', N'Sánchez Flores', '19451127', 'F', N'Sector 05', N'SIS', '20260724'),
    ('99000004', 'GC-0004', N'Nadia Belén', N'Cruz Chávez', '20181028', 'F', N'Sector 03', N'SIS', '20260610'),
    ('99000005', 'GC-0005', N'Jhonatan Alexander', N'Cruz Chávez', '20170715', 'M', N'Sector 01', N'Sin seguro', '20260410'),
    ('99000006', 'GC-0006', N'Alexis Adrián', N'Medina Vargas', '20061126', 'M', N'Sector 04', N'SIS', '20260905'),
    ('99000007', 'GC-0007', N'Miguel Ángel', N'Quispe Palacios', '20100327', 'M', N'Sector 05', N'SIS', '20260625'),
    ('99000008', 'GC-0008', N'Manuel Enrique', N'Díaz Paredes', '19760217', 'M', N'Sector 04', N'SIS', '20260730'),
    ('99000009', 'GC-0009', N'María Fernanda', N'Vásquez Salazar', '19431230', 'F', N'Sector 02', N'SIS', '20260616'),
    ('99000010', 'GC-0010', N'Jorge Luis', N'Campos Cruz', '20211011', 'M', N'Sector 01', N'SIS', '20260404'),
    ('99000011', 'GC-0011', N'Claudia Beatriz', N'Espinoza Alfaro', '19810105', 'F', N'Sector 03', N'EsSalud', '20260408'),
    ('99000012', 'GC-0012', N'José Manuel', N'León Zavaleta', '20240920', 'M', N'Sector 03', N'SIS', '20260421'),
    ('99000013', 'GC-0013', N'Héctor Raúl', N'Becerra Montalvo', '20200714', 'M', N'Sector 01', N'SIS', '20260819'),
    ('99000014', 'GC-0014', N'Sandra Patricia', N'Gutiérrez Alfaro', '19950219', 'F', N'Sector 04', N'SIS', '20260925'),
    ('99000015', 'GC-0015', N'Ana Lucía', N'Alvarado Cueva', '19400409', 'F', N'Sector 01', N'SIS', '20260720'),
    ('99000016', 'GC-0016', N'Ricardo Paolo', N'Cárdenas Medina', '19890128', 'M', N'Sector 03', N'SIS', '20260428'),
    ('99000017', 'GC-0017', N'Juan Diego', N'Figueroa Castillo', '20021210', 'M', N'Sector 01', N'SIS', '20260521'),
    ('99000018', 'GC-0018', N'Sergio Martín', N'Chávez Silva', '20090922', 'M', N'Sector 04', N'SIS', '20260912'),
    ('99000019', 'GC-0019', N'Liliana Maribel', N'León Pérez', '20210904', 'F', N'Sector 05', N'SIS', '20260519'),
    ('99000020', 'GC-0020', N'Yessenia Milagros', N'Ramos Quispe', '19921028', 'F', N'Sector 02', N'Otro', '20260407'),
    ('99000021', 'GC-0021', N'Alessandra Dayana', N'Cárdenas Ponce', '19830904', 'F', N'Sector 01', N'SIS', '20260622'),
    ('99000022', 'GC-0022', N'Jazmín Guadalupe', N'Figueroa Zamora', '20060719', 'F', N'Sector 04', N'EsSalud', '20260423'),
    ('99000023', 'GC-0023', N'Víctor Hugo', N'Córdova Cueva', '19400314', 'M', N'Sector 02', N'SIS', '20260429'),
    ('99000024', 'GC-0024', N'Valeria Andrea', N'García Medina', '19800219', 'F', N'Sector 01', N'SIS', '20260505'),
    ('99000025', 'GC-0025', N'Carlos Eduardo', N'Ramírez Morales', '20220825', 'M', N'Sector 02', N'SIS', '20260929'),
    ('99000026', 'GC-0026', N'José Manuel', N'León López', '20210719', 'M', N'Sector 03', N'SIS', '20260512'),
    ('99000027', 'GC-0027', N'Marco Antonio', N'Morales Vásquez', '19630319', 'M', N'Sector 05', N'SIS', '20260522'),
    ('99000028', 'GC-0028', N'Carlos Eduardo', N'Paredes Herrera', '19780411', 'M', N'Sector 01', N'SIS', '20260409'),
    ('99000029', 'GC-0029', N'Óscar David', N'Ramírez Alfaro', '20260524', 'M', N'Sector 05', N'SIS', '20260817'),
    ('99000030', 'GC-0030', N'Noelia Alexandra', N'Montalvo Medina', '19810327', 'F', N'Sector 03', N'SIS', '20260806'),
    ('99000031', 'GC-0031', N'Brayan Jesús', N'Palacios Pérez', '20170103', 'M', N'Sector 03', N'EsSalud', '20260918'),
    ('99000032', 'GC-0032', N'Jhonatan Alexander', N'Villanueva Aguilar', '20071212', 'M', N'Sector 04', N'EsSalud', '20260817'),
    ('99000033', 'GC-0033', N'Kevin Esteban', N'Cruz Chávez', '19830928', 'M', N'Sector 04', N'SIS', '20260515'),
    ('99000034', 'GC-0034', N'Luis Alberto', N'Herrera García', '20151113', 'M', N'Sector 01', N'EsSalud', '20260517'),
    ('99000035', 'GC-0035', N'Franco Nicolás', N'Vargas Becerra', '19890603', 'M', N'Sector 05', N'SIS', '20260702'),
    ('99000036', 'GC-0036', N'Lucía Isabel', N'Cueva Ponce', '19840802', 'F', N'Sector 03', N'Sin seguro', '20260613'),
    ('99000037', 'GC-0037', N'Juan Diego', N'Cueva Figueroa', '19851210', 'M', N'Sector 04', N'SIS', '20260914'),
    ('99000038', 'GC-0038', N'Mónica Cecilia', N'Vargas Sánchez', '19650203', 'F', N'Sector 04', N'SIS', '20260617'),
    ('99000039', 'GC-0039', N'Renato Sebastián', N'Palacios Acosta', '19480912', 'M', N'Sector 04', N'EsSalud', '20260724'),
    ('99000040', 'GC-0040', N'Jorge Luis', N'Zamora Ramos', '20251109', 'M', N'Sector 03', N'SIS', '20260610'),
    ('99000041', 'GC-0041', N'Julio César', N'Benites Torres', '20090227', 'M', N'Sector 03', N'SIS', '20260907'),
    ('99000042', 'GC-0042', N'Luis Alberto', N'Torres Díaz', '19970816', 'M', N'Sector 05', N'SIS', '20260414'),
    ('99000043', 'GC-0043', N'Luis Alberto', N'Morales Quispe', '19740131', 'M', N'Sector 01', N'SIS', '20260509'),
    ('99000044', 'GC-0044', N'Edwin Mauricio', N'García Benites', '19431106', 'M', N'Sector 05', N'EsSalud', '20260915'),
    ('99000045', 'GC-0045', N'David Alejandro', N'Benites Ramos', '19540702', 'M', N'Sector 01', N'SIS', '20260515'),
    ('99000046', 'GC-0046', N'Rosa Elena', N'Morales Silva', '19700608', 'F', N'Sector 02', N'SIS', '20260720'),
    ('99000047', 'GC-0047', N'Carmen Rosa', N'Herrera Benites', '19820514', 'F', N'Sector 02', N'SIS', '20260819'),
    ('99000048', 'GC-0048', N'Nadia Belén', N'Díaz López', '19990515', 'F', N'Sector 05', N'SIS', '20260722'),
    ('99000049', 'GC-0049', N'Nadia Belén', N'Navarro Reyes', '20230519', 'F', N'Sector 04', N'SIS', '20260926'),
    ('99000050', 'GC-0050', N'Marco Antonio', N'Alfaro Acosta', '20260709', 'M', N'Sector 02', N'Sin seguro', '20260823'),
    ('99000051', 'GC-0051', N'Óscar David', N'Chávez Rojas', '19850201', 'M', N'Sector 02', N'SIS', '20260419'),
    ('99000052', 'GC-0052', N'Brayan Jesús', N'Chávez Campos', '19831021', 'M', N'Sector 01', N'Sin seguro', '20260807'),
    ('99000053', 'GC-0053', N'Liliana Maribel', N'Ramos Cueva', '20230602', 'F', N'Sector 05', N'SIS', '20260813'),
    ('99000054', 'GC-0054', N'Elena Lucero', N'Silva Zavaleta', '20040723', 'F', N'Sector 02', N'SIS', '20260510'),
    ('99000055', 'GC-0055', N'Gabriela Estefanía', N'Quispe León', '19550320', 'F', N'Sector 05', N'SIS', '20260828'),
    ('99000056', 'GC-0056', N'Kevin Esteban', N'Campos Vásquez', '19920314', 'M', N'Sector 02', N'SIS', '20260918'),
    ('99000057', 'GC-0057', N'Nadia Belén', N'Quispe Ramos', '19750909', 'F', N'Sector 05', N'SIS', '20260408'),
    ('99000058', 'GC-0058', N'Renato Sebastián', N'Palacios Aguilar', '20010820', 'M', N'Sector 04', N'SIS', '20260908'),
    ('99000059', 'GC-0059', N'Diego Armando', N'Chávez Espinoza', '19970306', 'M', N'Sector 03', N'SIS', '20260918'),
    ('99000060', 'GC-0060', N'Sergio Martín', N'Acosta Díaz', '20110509', 'M', N'Sector 02', N'SIS', '20260513'),
    ('99000061', 'GC-0061', N'Yessenia Milagros', N'Rojas Becerra', '20260428', 'F', N'Sector 01', N'SIS', '20260623'),
    ('99000062', 'GC-0062', N'Daniela Sofía', N'Zavaleta Campos', '20170506', 'F', N'Sector 02', N'SIS', '20260528'),
    ('99000063', 'GC-0063', N'Paola Elizabeth', N'Montalvo Huamán', '20251111', 'F', N'Sector 05', N'SIS', '20260709'),
    ('99000064', 'GC-0064', N'Esther Mariana', N'García Cárdenas', '19920504', 'F', N'Sector 01', N'SIS', '20260726'),
    ('99000065', 'GC-0065', N'Jazmín Guadalupe', N'Pérez Ponce', '19910501', 'F', N'Sector 05', N'SIS', '20260921'),
    ('99000066', 'GC-0066', N'Óscar David', N'Pérez López', '19720920', 'M', N'Sector 02', N'SIS', '20260517'),
    ('99000067', 'GC-0067', N'Esther Mariana', N'Díaz Mendoza', '20100831', 'F', N'Sector 04', N'EsSalud', '20260527'),
    ('99000068', 'GC-0068', N'Camila Alejandra', N'Reyes Rodríguez', '20100510', 'F', N'Sector 03', N'SIS', '20260918'),
    ('99000069', 'GC-0069', N'Luis Alberto', N'Chávez Cruz', '20200525', 'M', N'Sector 04', N'Sin seguro', '20260429'),
    ('99000070', 'GC-0070', N'Jazmín Guadalupe', N'Castillo Cueva', '20140711', 'F', N'Sector 02', N'SIS', '20260820'),
    ('99000071', 'GC-0071', N'Andrea Victoria', N'Salazar Valverde', '19790724', 'F', N'Sector 04', N'SIS', '20260602'),
    ('99000072', 'GC-0072', N'Liliana Maribel', N'Córdova Campos', '19760729', 'F', N'Sector 02', N'SIS', '20260828'),
    ('99000073', 'GC-0073', N'José Manuel', N'Paredes Figueroa', '19750103', 'M', N'Sector 03', N'Sin seguro', '20260717'),
    ('99000074', 'GC-0074', N'Valeria Andrea', N'Morales Acosta', '20161229', 'F', N'Sector 05', N'SIS', '20260807'),
    ('99000075', 'GC-0075', N'Andrea Victoria', N'Silva Ramos', '20121016', 'F', N'Sector 05', N'Sin seguro', '20260625'),
    ('99000076', 'GC-0076', N'Camila Alejandra', N'Alfaro Gutiérrez', '20021011', 'F', N'Sector 01', N'Sin seguro', '20260720'),
    ('99000077', 'GC-0077', N'Alonso Gabriel', N'Aguilar Benites', '20040817', 'M', N'Sector 04', N'Sin seguro', '20260612'),
    ('99000078', 'GC-0078', N'Franco Nicolás', N'Alfaro Zamora', '19950223', 'M', N'Sector 02', N'SIS', '20260830'),
    ('99000079', 'GC-0079', N'Fiorella Nicole', N'Quispe Zamora', '19800816', 'F', N'Sector 04', N'SIS', '20260606'),
    ('99000080', 'GC-0080', N'Diana Carolina', N'Morales Vásquez', '20210129', 'F', N'Sector 01', N'SIS', '20260709'),
    ('99000081', 'GC-0081', N'Alonso Gabriel', N'Palacios Cruz', '19590803', 'M', N'Sector 05', N'SIS', '20260701'),
    ('99000082', 'GC-0082', N'Andrés Felipe', N'Torres Mendoza', '20100226', 'M', N'Sector 04', N'SIS', '20260729'),
    ('99000083', 'GC-0083', N'Brenda Aylin', N'Gutiérrez García', '19990906', 'F', N'Sector 03', N'SIS', '20260903'),
    ('99000084', 'GC-0084', N'Carmen Rosa', N'Paredes Rojas', '20070701', 'F', N'Sector 02', N'Sin seguro', '20260729'),
    ('99000085', 'GC-0085', N'Héctor Raúl', N'Silva Huamán', '19981128', 'M', N'Sector 04', N'SIS', '20260517'),
    ('99000086', 'GC-0086', N'Kevin Esteban', N'Palacios Silva', '20240821', 'M', N'Sector 01', N'SIS', '20260822'),
    ('99000087', 'GC-0087', N'Lucía Isabel', N'Zamora Figueroa', '19650415', 'F', N'Sector 05', N'SIS', '20260619'),
    ('99000088', 'GC-0088', N'Lucía Isabel', N'Chávez Morales', '19851025', 'F', N'Sector 05', N'SIS', '20260802'),
    ('99000089', 'GC-0089', N'Claudia Beatriz', N'Silva Torres', '19880525', 'F', N'Sector 03', N'SIS', '20260820'),
    ('99000090', 'GC-0090', N'Juan Diego', N'Zavaleta Espinoza', '20250716', 'M', N'Sector 04', N'SIS', '20260814'),
    ('99000091', 'GC-0091', N'Víctor Hugo', N'Cruz Díaz', '19580303', 'M', N'Sector 02', N'SIS', '20260511'),
    ('99000092', 'GC-0092', N'María Fernanda', N'Navarro Quispe', '20260221', 'F', N'Sector 04', N'SIS', '20260419'),
    ('99000093', 'GC-0093', N'César Augusto', N'Rojas Ramos', '19820408', 'M', N'Sector 02', N'SIS', '20260528'),
    ('99000094', 'GC-0094', N'Milagros Fátima', N'Morales Vásquez', '20240130', 'F', N'Sector 02', N'SIS', '20260424'),
    ('99000095', 'GC-0095', N'Karla Vanessa', N'Reyes Zavaleta', '19840613', 'F', N'Sector 04', N'Otro', '20260611'),
    ('99000096', 'GC-0096', N'Pedro Antonio', N'Palacios Castillo', '19981216', 'M', N'Sector 04', N'SIS', '20260514'),
    ('99000097', 'GC-0097', N'Roberto Daniel', N'Vásquez Aguilar', '19840717', 'M', N'Sector 04', N'SIS', '20260420'),
    ('99000098', 'GC-0098', N'Luis Alberto', N'Ortega Medina', '20041206', 'M', N'Sector 02', N'SIS', '20260731'),
    ('99000099', 'GC-0099', N'Alexis Adrián', N'Mendoza Montalvo', '20031030', 'M', N'Sector 04', N'SIS', '20260716'),
    ('99000100', 'GC-0100', N'Martha Lucía', N'Zavaleta Cruz', '19850622', 'F', N'Sector 04', N'SIS', '20260730')
) AS v(DNI, CodigoPaciente, Nombres, Apellidos, FechaNacimiento, Sexo,
       SectorResidencia, TipoSeguro, FechaRegistro)
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.Pacientes AS p
    WHERE p.DNI = v.DNI OR p.CodigoPaciente = v.CodigoPaciente
);
GO

-- Lote 2 de 4: pacientes 0101-0200
INSERT INTO dbo.Pacientes
    (DNI, CodigoPaciente, Nombres, Apellidos, FechaNacimiento, Sexo,
     SectorResidencia, TipoSeguro, FechaRegistro)
SELECT v.DNI, v.CodigoPaciente, v.Nombres, v.Apellidos, v.FechaNacimiento,
       v.Sexo, v.SectorResidencia, v.TipoSeguro, v.FechaRegistro
FROM (VALUES
    ('99000101', 'GC-0101', N'Alonso Gabriel', N'Salazar Silva', '19490116', 'M', N'Sector 01', N'SIS', '20260427'),
    ('99000102', 'GC-0102', N'Andrés Felipe', N'Rojas Torres', '19710316', 'M', N'Sector 04', N'SIS', '20260811'),
    ('99000103', 'GC-0103', N'Sandra Patricia', N'León Gutiérrez', '19640128', 'F', N'Sector 01', N'SIS', '20260701'),
    ('99000104', 'GC-0104', N'Franco Nicolás', N'Alfaro León', '20200325', 'M', N'Sector 01', N'SIS', '20260416'),
    ('99000105', 'GC-0105', N'Gabriela Estefanía', N'Salazar Ramírez', '19670308', 'F', N'Sector 02', N'Sin seguro', '20260816'),
    ('99000106', 'GC-0106', N'María Fernanda', N'García Ponce', '19670417', 'F', N'Sector 03', N'SIS', '20260629'),
    ('99000107', 'GC-0107', N'Víctor Hugo', N'Ponce Paredes', '20251111', 'M', N'Sector 05', N'EsSalud', '20260527'),
    ('99000108', 'GC-0108', N'Milagros Fátima', N'Vargas Campos', '19891205', 'F', N'Sector 05', N'SIS', '20260427'),
    ('99000109', 'GC-0109', N'David Alejandro', N'Ramírez Zamora', '19730814', 'M', N'Sector 03', N'SIS', '20260702'),
    ('99000110', 'GC-0110', N'Paola Elizabeth', N'Alfaro Figueroa', '20240512', 'F', N'Sector 01', N'Sin seguro', '20260617'),
    ('99000111', 'GC-0111', N'Ana Lucía', N'Vargas Flores', '19700724', 'F', N'Sector 02', N'SIS', '20260401'),
    ('99000112', 'GC-0112', N'Edwin Mauricio', N'Ortega Herrera', '19981104', 'M', N'Sector 05', N'EsSalud', '20260614'),
    ('99000113', 'GC-0113', N'Renato Sebastián', N'Campos Gutiérrez', '19480509', 'M', N'Sector 04', N'SIS', '20260621'),
    ('99000114', 'GC-0114', N'Andrea Victoria', N'Figueroa Cueva', '19761107', 'F', N'Sector 03', N'SIS', '20260523'),
    ('99000115', 'GC-0115', N'Ana Lucía', N'Aguilar Córdova', '19761001', 'F', N'Sector 03', N'SIS', '20260418'),
    ('99000116', 'GC-0116', N'Fernando Javier', N'Ramos Zavaleta', '19870310', 'M', N'Sector 03', N'SIS', '20260422'),
    ('99000117', 'GC-0117', N'Camila Alejandra', N'Huamán Castillo', '20140426', 'F', N'Sector 04', N'SIS', '20260608'),
    ('99000118', 'GC-0118', N'Valeria Andrea', N'Alfaro Espinoza', '19921120', 'F', N'Sector 03', N'SIS', '20260818'),
    ('99000119', 'GC-0119', N'Lucía Isabel', N'Salazar Montalvo', '19970908', 'F', N'Sector 04', N'SIS', '20260424'),
    ('99000120', 'GC-0120', N'María Fernanda', N'Vargas Silva', '19580302', 'F', N'Sector 04', N'SIS', '20260514'),
    ('99000121', 'GC-0121', N'Daniela Sofía', N'Pérez Chávez', '19730901', 'F', N'Sector 02', N'SIS', '20260802'),
    ('99000122', 'GC-0122', N'María Fernanda', N'Reyes Gutiérrez', '20020415', 'F', N'Sector 01', N'SIS', '20260604'),
    ('99000123', 'GC-0123', N'Rosa Elena', N'Aguilar Ponce', '20030605', 'F', N'Sector 01', N'Sin seguro', '20260513'),
    ('99000124', 'GC-0124', N'Tatiana Gabriela', N'Espinoza Rojas', '19980612', 'F', N'Sector 01', N'SIS', '20260730'),
    ('99000125', 'GC-0125', N'Martha Lucía', N'Montalvo Benites', '20151215', 'F', N'Sector 02', N'SIS', '20260707'),
    ('99000126', 'GC-0126', N'Óscar David', N'Gutiérrez Torres', '20110903', 'M', N'Sector 05', N'SIS', '20260916'),
    ('99000127', 'GC-0127', N'Miguel Ángel', N'Flores García', '20181127', 'M', N'Sector 05', N'EsSalud', '20260501'),
    ('99000128', 'GC-0128', N'Alonso Gabriel', N'Sánchez Torres', '20030205', 'M', N'Sector 02', N'SIS', '20260915'),
    ('99000129', 'GC-0129', N'David Alejandro', N'Sánchez Zavaleta', '20180926', 'M', N'Sector 04', N'SIS', '20260614'),
    ('99000130', 'GC-0130', N'Alexis Adrián', N'Montalvo Alfaro', '20140112', 'M', N'Sector 01', N'SIS', '20260731'),
    ('99000131', 'GC-0131', N'Martha Lucía', N'Navarro Mendoza', '19530306', 'F', N'Sector 04', N'SIS', '20260630'),
    ('99000132', 'GC-0132', N'Martha Lucía', N'Zavaleta Palacios', '19710719', 'F', N'Sector 01', N'SIS', '20260609'),
    ('99000133', 'GC-0133', N'Manuel Enrique', N'Vásquez Salazar', '19810611', 'M', N'Sector 05', N'SIS', '20260719'),
    ('99000134', 'GC-0134', N'Julio César', N'Montalvo Paredes', '19900630', 'M', N'Sector 03', N'SIS', '20260802'),
    ('99000135', 'GC-0135', N'Gabriela Estefanía', N'Cruz Salazar', '19690330', 'F', N'Sector 02', N'SIS', '20260926'),
    ('99000136', 'GC-0136', N'Sergio Martín', N'Ramos Reyes', '19720825', 'M', N'Sector 04', N'SIS', '20260510'),
    ('99000137', 'GC-0137', N'Pedro Antonio', N'García Ramos', '19810703', 'M', N'Sector 04', N'Otro', '20260514'),
    ('99000138', 'GC-0138', N'Daniela Sofía', N'Valverde Sánchez', '20140822', 'F', N'Sector 01', N'SIS', '20260504'),
    ('99000139', 'GC-0139', N'Óscar David', N'Becerra Mendoza', '20090223', 'M', N'Sector 02', N'SIS', '20260920'),
    ('99000140', 'GC-0140', N'Juan Diego', N'Herrera Castillo', '19551119', 'M', N'Sector 02', N'SIS', '20260419'),
    ('99000141', 'GC-0141', N'Kevin Esteban', N'Silva Morales', '20190101', 'M', N'Sector 05', N'SIS', '20260906'),
    ('99000142', 'GC-0142', N'Nadia Belén', N'Mendoza Chávez', '20111228', 'F', N'Sector 05', N'SIS', '20260828'),
    ('99000143', 'GC-0143', N'Claudia Beatriz', N'Espinoza Zavaleta', '20061207', 'F', N'Sector 04', N'EsSalud', '20260626'),
    ('99000144', 'GC-0144', N'Tatiana Gabriela', N'Vásquez Alfaro', '20240721', 'F', N'Sector 03', N'Sin seguro', '20260613'),
    ('99000145', 'GC-0145', N'Alonso Gabriel', N'Huamán Salazar', '20010717', 'M', N'Sector 02', N'SIS', '20260826'),
    ('99000146', 'GC-0146', N'Diego Armando', N'Silva Morales', '20260223', 'M', N'Sector 01', N'SIS', '20260611'),
    ('99000147', 'GC-0147', N'Martha Lucía', N'López Navarro', '20010418', 'F', N'Sector 05', N'SIS', '20260625'),
    ('99000148', 'GC-0148', N'Camila Alejandra', N'Rojas Ortega', '20000329', 'F', N'Sector 05', N'SIS', '20260713'),
    ('99000149', 'GC-0149', N'Fiorella Nicole', N'Acosta Cueva', '20000418', 'F', N'Sector 05', N'Otro', '20260822'),
    ('99000150', 'GC-0150', N'Noelia Alexandra', N'Becerra Rojas', '20091008', 'F', N'Sector 01', N'Sin seguro', '20260914'),
    ('99000151', 'GC-0151', N'Miguel Ángel', N'Castillo Paredes', '20201018', 'M', N'Sector 05', N'SIS', '20260826'),
    ('99000152', 'GC-0152', N'Edwin Mauricio', N'Huamán Cueva', '20040512', 'M', N'Sector 01', N'SIS', '20260526'),
    ('99000153', 'GC-0153', N'Alessandra Dayana', N'Pérez Vásquez', '19860824', 'F', N'Sector 03', N'SIS', '20260810'),
    ('99000154', 'GC-0154', N'Mónica Cecilia', N'Córdova Alvarado', '19580301', 'F', N'Sector 03', N'SIS', '20260924'),
    ('99000155', 'GC-0155', N'Miguel Ángel', N'Torres Cruz', '20231122', 'M', N'Sector 03', N'Sin seguro', '20260929'),
    ('99000156', 'GC-0156', N'Karla Vanessa', N'Rojas Acosta', '20160327', 'F', N'Sector 01', N'SIS', '20260612'),
    ('99000157', 'GC-0157', N'Alonso Gabriel', N'Becerra Villanueva', '19470428', 'M', N'Sector 05', N'SIS', '20260704'),
    ('99000158', 'GC-0158', N'María Fernanda', N'Valverde Sánchez', '20120702', 'F', N'Sector 01', N'SIS', '20260508'),
    ('99000159', 'GC-0159', N'Andrea Victoria', N'Salazar Palacios', '19391122', 'F', N'Sector 01', N'Sin seguro', '20260606'),
    ('99000160', 'GC-0160', N'Ricardo Paolo', N'Valverde Rodríguez', '20161117', 'M', N'Sector 05', N'SIS', '20260922'),
    ('99000161', 'GC-0161', N'Sandra Patricia', N'Palacios Díaz', '20170122', 'F', N'Sector 05', N'SIS', '20260908'),
    ('99000162', 'GC-0162', N'Alonso Gabriel', N'Ortega Acosta', '19991020', 'M', N'Sector 02', N'SIS', '20260804'),
    ('99000163', 'GC-0163', N'Carlos Eduardo', N'Medina Huamán', '20120410', 'M', N'Sector 01', N'SIS', '20260405'),
    ('99000164', 'GC-0164', N'Juan Diego', N'Córdova Vásquez', '19780119', 'M', N'Sector 03', N'Sin seguro', '20260719'),
    ('99000165', 'GC-0165', N'David Alejandro', N'Cueva Valverde', '20240314', 'M', N'Sector 04', N'SIS', '20260424'),
    ('99000166', 'GC-0166', N'Elena Lucero', N'Córdova Vásquez', '20020919', 'F', N'Sector 04', N'SIS', '20260706'),
    ('99000167', 'GC-0167', N'David Alejandro', N'Córdova Aguilar', '19950322', 'M', N'Sector 01', N'SIS', '20260412'),
    ('99000168', 'GC-0168', N'Nadia Belén', N'Vargas Rodríguez', '20010907', 'F', N'Sector 03', N'SIS', '20260412'),
    ('99000169', 'GC-0169', N'Tatiana Gabriela', N'Zamora Becerra', '20090122', 'F', N'Sector 04', N'SIS', '20260914'),
    ('99000170', 'GC-0170', N'David Alejandro', N'Medina Vargas', '20220126', 'M', N'Sector 02', N'EsSalud', '20260918'),
    ('99000171', 'GC-0171', N'Renato Sebastián', N'Torres Palacios', '19760909', 'M', N'Sector 03', N'Sin seguro', '20260415'),
    ('99000172', 'GC-0172', N'Cristian Eduardo', N'Alvarado Medina', '19390319', 'M', N'Sector 04', N'SIS', '20260811'),
    ('99000173', 'GC-0173', N'Ricardo Paolo', N'Espinoza Figueroa', '20210107', 'M', N'Sector 02', N'SIS', '20260805'),
    ('99000174', 'GC-0174', N'Carmen Rosa', N'Montalvo Castillo', '19681029', 'F', N'Sector 02', N'SIS', '20260612'),
    ('99000175', 'GC-0175', N'Paola Elizabeth', N'Acosta Figueroa', '20160628', 'F', N'Sector 03', N'SIS', '20260728'),
    ('99000176', 'GC-0176', N'Diego Armando', N'Salazar Figueroa', '19921124', 'M', N'Sector 02', N'SIS', '20260816'),
    ('99000177', 'GC-0177', N'Carmen Rosa', N'Morales León', '19980925', 'F', N'Sector 04', N'Otro', '20260616'),
    ('99000178', 'GC-0178', N'Liliana Maribel', N'Espinoza Campos', '19470729', 'F', N'Sector 04', N'Sin seguro', '20260508'),
    ('99000179', 'GC-0179', N'Franco Nicolás', N'Córdova Medina', '20170914', 'M', N'Sector 03', N'SIS', '20260818'),
    ('99000180', 'GC-0180', N'Noelia Alexandra', N'Villanueva Becerra', '19770818', 'F', N'Sector 03', N'SIS', '20260407'),
    ('99000181', 'GC-0181', N'Alonso Gabriel', N'Rojas Cárdenas', '19860503', 'M', N'Sector 01', N'SIS', '20260906'),
    ('99000182', 'GC-0182', N'Daniela Sofía', N'Cruz Torres', '20050409', 'F', N'Sector 04', N'SIS', '20260601'),
    ('99000183', 'GC-0183', N'Kevin Esteban', N'Vásquez Torres', '19721028', 'M', N'Sector 05', N'SIS', '20260927'),
    ('99000184', 'GC-0184', N'Juan Diego', N'León Acosta', '19981125', 'M', N'Sector 04', N'SIS', '20260930'),
    ('99000185', 'GC-0185', N'Andrés Felipe', N'Ponce Torres', '20240628', 'M', N'Sector 03', N'SIS', '20260416'),
    ('99000186', 'GC-0186', N'Edwin Mauricio', N'Ramos Huamán', '20020707', 'M', N'Sector 03', N'SIS', '20260714'),
    ('99000187', 'GC-0187', N'Diana Carolina', N'García Quispe', '19590817', 'F', N'Sector 04', N'Sin seguro', '20260711'),
    ('99000188', 'GC-0188', N'Paola Elizabeth', N'Becerra López', '19570513', 'F', N'Sector 05', N'SIS', '20260404'),
    ('99000189', 'GC-0189', N'Paola Elizabeth', N'Montalvo Salazar', '19890428', 'F', N'Sector 04', N'SIS', '20260403'),
    ('99000190', 'GC-0190', N'Martha Lucía', N'Benites Acosta', '20100803', 'F', N'Sector 01', N'Sin seguro', '20260927'),
    ('99000191', 'GC-0191', N'Alessandra Dayana', N'Chávez Cárdenas', '20160906', 'F', N'Sector 03', N'SIS', '20260503'),
    ('99000192', 'GC-0192', N'Liliana Maribel', N'Pérez Navarro', '19730514', 'F', N'Sector 03', N'SIS', '20260814'),
    ('99000193', 'GC-0193', N'Martha Lucía', N'Ramírez Palacios', '20200703', 'F', N'Sector 03', N'Sin seguro', '20260709'),
    ('99000194', 'GC-0194', N'Franco Nicolás', N'Gutiérrez García', '20240912', 'M', N'Sector 04', N'SIS', '20260405'),
    ('99000195', 'GC-0195', N'Fernando Javier', N'Flores Castillo', '20250616', 'M', N'Sector 02', N'Sin seguro', '20260420'),
    ('99000196', 'GC-0196', N'Andrea Victoria', N'Rojas Ramírez', '20150831', 'F', N'Sector 05', N'Sin seguro', '20260924'),
    ('99000197', 'GC-0197', N'Rosa Elena', N'Cárdenas Montalvo', '20110827', 'F', N'Sector 02', N'SIS', '20260508'),
    ('99000198', 'GC-0198', N'Alonso Gabriel', N'Espinoza Córdova', '20140624', 'M', N'Sector 04', N'SIS', '20260522'),
    ('99000199', 'GC-0199', N'Óscar David', N'Alvarado Navarro', '19820829', 'M', N'Sector 02', N'SIS', '20260711'),
    ('99000200', 'GC-0200', N'Karla Vanessa', N'Gutiérrez Ramírez', '20170308', 'F', N'Sector 01', N'SIS', '20260722')
) AS v(DNI, CodigoPaciente, Nombres, Apellidos, FechaNacimiento, Sexo,
       SectorResidencia, TipoSeguro, FechaRegistro)
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.Pacientes AS p
    WHERE p.DNI = v.DNI OR p.CodigoPaciente = v.CodigoPaciente
);
GO

-- Lote 3 de 4: pacientes 0201-0300
INSERT INTO dbo.Pacientes
    (DNI, CodigoPaciente, Nombres, Apellidos, FechaNacimiento, Sexo,
     SectorResidencia, TipoSeguro, FechaRegistro)
SELECT v.DNI, v.CodigoPaciente, v.Nombres, v.Apellidos, v.FechaNacimiento,
       v.Sexo, v.SectorResidencia, v.TipoSeguro, v.FechaRegistro
FROM (VALUES
    ('99000201', 'GC-0201', N'Víctor Hugo', N'Espinoza Quispe', '19900111', 'M', N'Sector 02', N'SIS', '20260423'),
    ('99000202', 'GC-0202', N'Alessandra Dayana', N'Zavaleta Sánchez', '20220414', 'F', N'Sector 03', N'SIS', '20260415'),
    ('99000203', 'GC-0203', N'Sergio Martín', N'León Campos', '20211201', 'M', N'Sector 02', N'SIS', '20260407'),
    ('99000204', 'GC-0204', N'César Augusto', N'Medina Zavaleta', '20090729', 'M', N'Sector 01', N'SIS', '20260717'),
    ('99000205', 'GC-0205', N'Carlos Eduardo', N'Benites Montalvo', '20241108', 'M', N'Sector 05', N'SIS', '20260413'),
    ('99000206', 'GC-0206', N'María Fernanda', N'Cárdenas López', '19741125', 'F', N'Sector 02', N'SIS', '20260404'),
    ('99000207', 'GC-0207', N'José Manuel', N'Benites Córdova', '19791005', 'M', N'Sector 04', N'SIS', '20260417'),
    ('99000208', 'GC-0208', N'Ricardo Paolo', N'Becerra Acosta', '19800112', 'M', N'Sector 01', N'SIS', '20260502'),
    ('99000209', 'GC-0209', N'Elena Lucero', N'Díaz Herrera', '19970418', 'F', N'Sector 04', N'SIS', '20260416'),
    ('99000210', 'GC-0210', N'Cristian Eduardo', N'Sánchez Medina', '20090307', 'M', N'Sector 05', N'SIS', '20260412'),
    ('99000211', 'GC-0211', N'Lucía Isabel', N'Montalvo Ramírez', '20100131', 'F', N'Sector 05', N'Sin seguro', '20260611'),
    ('99000212', 'GC-0212', N'Brayan Jesús', N'Medina Valverde', '20200110', 'M', N'Sector 05', N'SIS', '20260804'),
    ('99000213', 'GC-0213', N'Diana Carolina', N'Villanueva Cárdenas', '19731130', 'F', N'Sector 03', N'EsSalud', '20260419'),
    ('99000214', 'GC-0214', N'Tatiana Gabriela', N'Medina Palacios', '19970106', 'F', N'Sector 05', N'SIS', '20260428'),
    ('99000215', 'GC-0215', N'Franco Nicolás', N'Cárdenas León', '19770406', 'M', N'Sector 05', N'SIS', '20260706'),
    ('99000216', 'GC-0216', N'Luis Alberto', N'Córdova Alfaro', '20231127', 'M', N'Sector 02', N'SIS', '20260817'),
    ('99000217', 'GC-0217', N'Rocío del Pilar', N'Becerra Reyes', '19730509', 'F', N'Sector 05', N'SIS', '20260927'),
    ('99000218', 'GC-0218', N'Andrés Felipe', N'Cabrera León', '20170527', 'M', N'Sector 04', N'EsSalud', '20260402'),
    ('99000219', 'GC-0219', N'Marco Antonio', N'Figueroa Mendoza', '20021228', 'M', N'Sector 02', N'SIS', '20260630'),
    ('99000220', 'GC-0220', N'Valeria Andrea', N'Ponce García', '19970903', 'F', N'Sector 02', N'Sin seguro', '20260423'),
    ('99000221', 'GC-0221', N'Alexis Adrián', N'Cueva Salazar', '19990620', 'M', N'Sector 02', N'SIS', '20260726'),
    ('99000222', 'GC-0222', N'Jorge Luis', N'Sánchez Montalvo', '19991004', 'M', N'Sector 03', N'SIS', '20260423'),
    ('99000223', 'GC-0223', N'Rosa Elena', N'Campos Alfaro', '19820411', 'F', N'Sector 04', N'SIS', '20260527'),
    ('99000224', 'GC-0224', N'Víctor Hugo', N'Ponce Díaz', '20120803', 'M', N'Sector 03', N'SIS', '20260512'),
    ('99000225', 'GC-0225', N'Martha Lucía', N'Herrera Villanueva', '19910408', 'F', N'Sector 05', N'SIS', '20260528'),
    ('99000226', 'GC-0226', N'Rocío del Pilar', N'Alfaro Reyes', '20170407', 'F', N'Sector 05', N'SIS', '20260517'),
    ('99000227', 'GC-0227', N'Óscar David', N'Alfaro Sánchez', '19641221', 'M', N'Sector 04', N'SIS', '20260924'),
    ('99000228', 'GC-0228', N'Nadia Belén', N'Valverde Morales', '19860321', 'F', N'Sector 04', N'SIS', '20260925'),
    ('99000229', 'GC-0229', N'Jazmín Guadalupe', N'Gutiérrez Ortega', '19701010', 'F', N'Sector 02', N'Sin seguro', '20260611'),
    ('99000230', 'GC-0230', N'Brenda Aylin', N'Zamora Cárdenas', '19780215', 'F', N'Sector 01', N'Sin seguro', '20260412'),
    ('99000231', 'GC-0231', N'Sergio Martín', N'Chávez López', '20171208', 'M', N'Sector 03', N'SIS', '20260520'),
    ('99000232', 'GC-0232', N'Roberto Daniel', N'Benites García', '19680209', 'M', N'Sector 05', N'SIS', '20260819'),
    ('99000233', 'GC-0233', N'Brenda Aylin', N'Alfaro Cárdenas', '19931006', 'F', N'Sector 05', N'EsSalud', '20260919'),
    ('99000234', 'GC-0234', N'Brenda Aylin', N'Córdova Morales', '20150121', 'F', N'Sector 02', N'SIS', '20260728'),
    ('99000235', 'GC-0235', N'Gabriela Estefanía', N'Aguilar Quispe', '20121009', 'F', N'Sector 04', N'SIS', '20260822'),
    ('99000236', 'GC-0236', N'Esther Mariana', N'Alfaro Córdova', '20260123', 'F', N'Sector 01', N'SIS', '20260421'),
    ('99000237', 'GC-0237', N'Edwin Mauricio', N'Chávez Alvarado', '20260313', 'M', N'Sector 05', N'SIS', '20260905'),
    ('99000238', 'GC-0238', N'Esther Mariana', N'Ramos Espinoza', '20050813', 'F', N'Sector 01', N'SIS', '20260611'),
    ('99000239', 'GC-0239', N'Tatiana Gabriela', N'Torres López', '20240511', 'F', N'Sector 01', N'SIS', '20260702'),
    ('99000240', 'GC-0240', N'Marco Antonio', N'Pérez León', '19940712', 'M', N'Sector 01', N'Sin seguro', '20260901'),
    ('99000241', 'GC-0241', N'Mónica Cecilia', N'Paredes Cárdenas', '19980226', 'F', N'Sector 04', N'SIS', '20260713'),
    ('99000242', 'GC-0242', N'Esther Mariana', N'Vásquez Ponce', '20241129', 'F', N'Sector 03', N'SIS', '20260501'),
    ('99000243', 'GC-0243', N'Elena Lucero', N'Quispe Reyes', '20240211', 'F', N'Sector 04', N'SIS', '20260508'),
    ('99000244', 'GC-0244', N'Camila Alejandra', N'Valverde Benites', '20240516', 'F', N'Sector 05', N'SIS', '20260406'),
    ('99000245', 'GC-0245', N'Valeria Andrea', N'Cárdenas Ortega', '19580727', 'F', N'Sector 03', N'SIS', '20260621'),
    ('99000246', 'GC-0246', N'Diana Carolina', N'Vargas Chávez', '19570807', 'F', N'Sector 02', N'SIS', '20260609'),
    ('99000247', 'GC-0247', N'Daniela Sofía', N'Villanueva García', '19721209', 'F', N'Sector 03', N'SIS', '20260614'),
    ('99000248', 'GC-0248', N'Sandra Patricia', N'Espinoza Chávez', '19890704', 'F', N'Sector 02', N'SIS', '20260629'),
    ('99000249', 'GC-0249', N'Víctor Hugo', N'Navarro Chávez', '19640426', 'M', N'Sector 03', N'Sin seguro', '20260517'),
    ('99000250', 'GC-0250', N'José Manuel', N'Paredes Salazar', '20180411', 'M', N'Sector 02', N'SIS', '20260610'),
    ('99000251', 'GC-0251', N'Óscar David', N'Cueva León', '20080529', 'M', N'Sector 01', N'SIS', '20260605'),
    ('99000252', 'GC-0252', N'María Fernanda', N'Zamora Zavaleta', '20010422', 'F', N'Sector 04', N'SIS', '20260930'),
    ('99000253', 'GC-0253', N'Franco Nicolás', N'Montalvo Alvarado', '19710429', 'M', N'Sector 01', N'EsSalud', '20260410'),
    ('99000254', 'GC-0254', N'Juan Diego', N'Córdova Benites', '19770827', 'M', N'Sector 03', N'SIS', '20260504'),
    ('99000255', 'GC-0255', N'César Augusto', N'López Alfaro', '20260404', 'M', N'Sector 05', N'EsSalud', '20260405'),
    ('99000256', 'GC-0256', N'Ana Lucía', N'Huamán Díaz', '20140507', 'F', N'Sector 04', N'SIS', '20260715'),
    ('99000257', 'GC-0257', N'Daniela Sofía', N'Medina Becerra', '19680607', 'F', N'Sector 03', N'Sin seguro', '20260402'),
    ('99000258', 'GC-0258', N'Alessandra Dayana', N'Zamora Cruz', '20111020', 'F', N'Sector 05', N'SIS', '20260706'),
    ('99000259', 'GC-0259', N'Elena Lucero', N'Zamora León', '20220831', 'F', N'Sector 05', N'SIS', '20260910'),
    ('99000260', 'GC-0260', N'Edwin Mauricio', N'Díaz Navarro', '19520302', 'M', N'Sector 04', N'SIS', '20260430'),
    ('99000261', 'GC-0261', N'Edwin Mauricio', N'López Ponce', '20011104', 'M', N'Sector 04', N'SIS', '20260922'),
    ('99000262', 'GC-0262', N'David Alejandro', N'León Espinoza', '19741217', 'M', N'Sector 04', N'SIS', '20260929'),
    ('99000263', 'GC-0263', N'Cristian Eduardo', N'Torres León', '20150706', 'M', N'Sector 05', N'SIS', '20260830'),
    ('99000264', 'GC-0264', N'Alessandra Dayana', N'Montalvo Reyes', '20220622', 'F', N'Sector 03', N'SIS', '20260926'),
    ('99000265', 'GC-0265', N'Martha Lucía', N'León Espinoza', '19600412', 'F', N'Sector 02', N'SIS', '20260822'),
    ('99000266', 'GC-0266', N'Esther Mariana', N'Navarro León', '20170614', 'F', N'Sector 02', N'SIS', '20260618'),
    ('99000267', 'GC-0267', N'Mónica Cecilia', N'Ortega Paredes', '20041027', 'F', N'Sector 05', N'SIS', '20260905'),
    ('99000268', 'GC-0268', N'Tatiana Gabriela', N'Huamán Villanueva', '20170225', 'F', N'Sector 02', N'SIS', '20260906'),
    ('99000269', 'GC-0269', N'Claudia Beatriz', N'Becerra Ramos', '19820628', 'F', N'Sector 01', N'Otro', '20260510'),
    ('99000270', 'GC-0270', N'Sergio Martín', N'Zavaleta Ramírez', '20080912', 'M', N'Sector 02', N'Sin seguro', '20260420'),
    ('99000271', 'GC-0271', N'Fernando Javier', N'Chávez Figueroa', '19870718', 'M', N'Sector 05', N'SIS', '20260524'),
    ('99000272', 'GC-0272', N'Carmen Rosa', N'León Ramírez', '20030710', 'F', N'Sector 03', N'EsSalud', '20260905'),
    ('99000273', 'GC-0273', N'Paola Elizabeth', N'Vásquez Aguilar', '19880415', 'F', N'Sector 05', N'SIS', '20260912'),
    ('99000274', 'GC-0274', N'Sandra Patricia', N'García Gutiérrez', '19870116', 'F', N'Sector 01', N'SIS', '20260704'),
    ('99000275', 'GC-0275', N'Alexis Adrián', N'López Ortega', '20010515', 'M', N'Sector 01', N'SIS', '20260831'),
    ('99000276', 'GC-0276', N'Ana Lucía', N'Palacios García', '19670609', 'F', N'Sector 03', N'SIS', '20260820'),
    ('99000277', 'GC-0277', N'Ricardo Paolo', N'Silva Vargas', '19970830', 'M', N'Sector 01', N'EsSalud', '20260416'),
    ('99000278', 'GC-0278', N'Manuel Enrique', N'Cueva Alvarado', '20221211', 'M', N'Sector 03', N'SIS', '20260622'),
    ('99000279', 'GC-0279', N'Kevin Esteban', N'Navarro Morales', '19450216', 'M', N'Sector 05', N'SIS', '20260526'),
    ('99000280', 'GC-0280', N'Esther Mariana', N'Gutiérrez Campos', '20170108', 'F', N'Sector 05', N'SIS', '20260729'),
    ('99000281', 'GC-0281', N'Carmen Rosa', N'Ponce Silva', '19540120', 'F', N'Sector 05', N'SIS', '20260426'),
    ('99000282', 'GC-0282', N'Elena Lucero', N'García Campos', '19610818', 'F', N'Sector 02', N'SIS', '20260414'),
    ('99000283', 'GC-0283', N'Manuel Enrique', N'Castillo Pérez', '20120127', 'M', N'Sector 03', N'SIS', '20260717'),
    ('99000284', 'GC-0284', N'Andrea Victoria', N'Castillo Villanueva', '19540501', 'F', N'Sector 02', N'SIS', '20260725'),
    ('99000285', 'GC-0285', N'Daniela Sofía', N'Díaz Rojas', '20161112', 'F', N'Sector 03', N'Sin seguro', '20260717'),
    ('99000286', 'GC-0286', N'Valeria Andrea', N'León Salazar', '19800804', 'F', N'Sector 02', N'SIS', '20260726'),
    ('99000287', 'GC-0287', N'Ana Lucía', N'Espinoza Montalvo', '20070505', 'F', N'Sector 05', N'SIS', '20260601'),
    ('99000288', 'GC-0288', N'David Alejandro', N'Pérez Ortega', '20170411', 'M', N'Sector 04', N'SIS', '20260724'),
    ('99000289', 'GC-0289', N'Miguel Ángel', N'García Palacios', '20080105', 'M', N'Sector 05', N'SIS', '20260405'),
    ('99000290', 'GC-0290', N'Sandra Patricia', N'Chávez Espinoza', '20091215', 'F', N'Sector 02', N'SIS', '20260604'),
    ('99000291', 'GC-0291', N'Alexis Adrián', N'Chávez Alvarado', '19911108', 'M', N'Sector 04', N'Sin seguro', '20260823'),
    ('99000292', 'GC-0292', N'Mónica Cecilia', N'Paredes León', '19381029', 'F', N'Sector 03', N'SIS', '20260726'),
    ('99000293', 'GC-0293', N'Julio César', N'Valverde Gutiérrez', '20001004', 'M', N'Sector 04', N'SIS', '20260728'),
    ('99000294', 'GC-0294', N'Sergio Martín', N'Campos Torres', '20090506', 'M', N'Sector 01', N'SIS', '20260630'),
    ('99000295', 'GC-0295', N'Tatiana Gabriela', N'Reyes Cabrera', '20260206', 'F', N'Sector 05', N'SIS', '20260502'),
    ('99000296', 'GC-0296', N'Andrea Victoria', N'Herrera Zavaleta', '20241030', 'F', N'Sector 05', N'SIS', '20260507'),
    ('99000297', 'GC-0297', N'Paola Elizabeth', N'Alfaro Paredes', '20161004', 'F', N'Sector 05', N'SIS', '20260514'),
    ('99000298', 'GC-0298', N'Héctor Raúl', N'Ramos Villanueva', '19830531', 'M', N'Sector 05', N'Otro', '20260621'),
    ('99000299', 'GC-0299', N'Víctor Hugo', N'Ponce Huamán', '20061120', 'M', N'Sector 01', N'Sin seguro', '20260627'),
    ('99000300', 'GC-0300', N'Julio César', N'Reyes Zavaleta', '19551104', 'M', N'Sector 05', N'SIS', '20260720')
) AS v(DNI, CodigoPaciente, Nombres, Apellidos, FechaNacimiento, Sexo,
       SectorResidencia, TipoSeguro, FechaRegistro)
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.Pacientes AS p
    WHERE p.DNI = v.DNI OR p.CodigoPaciente = v.CodigoPaciente
);
GO

-- Lote 4 de 4: pacientes 0301-0400
INSERT INTO dbo.Pacientes
    (DNI, CodigoPaciente, Nombres, Apellidos, FechaNacimiento, Sexo,
     SectorResidencia, TipoSeguro, FechaRegistro)
SELECT v.DNI, v.CodigoPaciente, v.Nombres, v.Apellidos, v.FechaNacimiento,
       v.Sexo, v.SectorResidencia, v.TipoSeguro, v.FechaRegistro
FROM (VALUES
    ('99000301', 'GC-0301', N'Elena Lucero', N'Palacios Alfaro', '20070222', 'F', N'Sector 01', N'SIS', '20260504'),
    ('99000302', 'GC-0302', N'Rosa Elena', N'Gutiérrez Campos', '20000405', 'F', N'Sector 04', N'SIS', '20260922'),
    ('99000303', 'GC-0303', N'Alessandra Dayana', N'Díaz Cueva', '20061016', 'F', N'Sector 05', N'SIS', '20260730'),
    ('99000304', 'GC-0304', N'Alonso Gabriel', N'Cueva Aguilar', '20090118', 'M', N'Sector 03', N'SIS', '20260604'),
    ('99000305', 'GC-0305', N'Marco Antonio', N'Salazar Cárdenas', '19720911', 'M', N'Sector 02', N'SIS', '20260405'),
    ('99000306', 'GC-0306', N'Miguel Ángel', N'Sánchez Cabrera', '19890515', 'M', N'Sector 03', N'SIS', '20260707'),
    ('99000307', 'GC-0307', N'Elena Lucero', N'Espinoza Figueroa', '19881016', 'F', N'Sector 01', N'Sin seguro', '20260927'),
    ('99000308', 'GC-0308', N'Jazmín Guadalupe', N'Espinoza Palacios', '19760922', 'F', N'Sector 04', N'SIS', '20260716'),
    ('99000309', 'GC-0309', N'Kevin Esteban', N'Silva Figueroa', '20161015', 'M', N'Sector 04', N'SIS', '20260811'),
    ('99000310', 'GC-0310', N'Sergio Martín', N'Rodríguez Cueva', '20021028', 'M', N'Sector 05', N'SIS', '20260503'),
    ('99000311', 'GC-0311', N'Milagros Fátima', N'Flores Benites', '19400813', 'F', N'Sector 03', N'SIS', '20260915'),
    ('99000312', 'GC-0312', N'Rosa Elena', N'Huamán Ramírez', '19760811', 'F', N'Sector 02', N'SIS', '20260927'),
    ('99000313', 'GC-0313', N'Víctor Hugo', N'Alfaro Cruz', '19651215', 'M', N'Sector 01', N'SIS', '20260626'),
    ('99000314', 'GC-0314', N'Rocío del Pilar', N'Benites Zamora', '20120502', 'F', N'Sector 04', N'SIS', '20260619'),
    ('99000315', 'GC-0315', N'Esther Mariana', N'Vásquez Ramírez', '19970301', 'F', N'Sector 03', N'SIS', '20260713'),
    ('99000316', 'GC-0316', N'Julio César', N'Ramos Mendoza', '20020302', 'M', N'Sector 05', N'SIS', '20260828'),
    ('99000317', 'GC-0317', N'Carlos Eduardo', N'Espinoza Cabrera', '19560322', 'M', N'Sector 04', N'Sin seguro', '20260704'),
    ('99000318', 'GC-0318', N'Camila Alejandra', N'Paredes Vargas', '19950402', 'F', N'Sector 04', N'EsSalud', '20260705'),
    ('99000319', 'GC-0319', N'Roberto Daniel', N'Gutiérrez Becerra', '19950328', 'M', N'Sector 02', N'SIS', '20260401'),
    ('99000320', 'GC-0320', N'Fiorella Nicole', N'Rojas Herrera', '20240824', 'F', N'Sector 01', N'SIS', '20260418'),
    ('99000321', 'GC-0321', N'Pedro Antonio', N'Palacios Sánchez', '19630923', 'M', N'Sector 03', N'SIS', '20260924'),
    ('99000322', 'GC-0322', N'Claudia Beatriz', N'Cruz Ponce', '20211030', 'F', N'Sector 05', N'SIS', '20260710'),
    ('99000323', 'GC-0323', N'Esther Mariana', N'Alvarado Salazar', '19740117', 'F', N'Sector 05', N'Sin seguro', '20260528'),
    ('99000324', 'GC-0324', N'Noelia Alexandra', N'Herrera Medina', '19791118', 'F', N'Sector 04', N'SIS', '20260409'),
    ('99000325', 'GC-0325', N'Jhonatan Alexander', N'Ramos Mendoza', '19910129', 'M', N'Sector 02', N'SIS', '20260629'),
    ('99000326', 'GC-0326', N'Jhonatan Alexander', N'Campos Zamora', '19950204', 'M', N'Sector 03', N'Sin seguro', '20260429'),
    ('99000327', 'GC-0327', N'Juan Diego', N'Flores Gutiérrez', '20160715', 'M', N'Sector 02', N'SIS', '20260818'),
    ('99000328', 'GC-0328', N'David Alejandro', N'Becerra Montalvo', '20111201', 'M', N'Sector 01', N'SIS', '20260408'),
    ('99000329', 'GC-0329', N'Pedro Antonio', N'Acosta Ramos', '20080310', 'M', N'Sector 01', N'SIS', '20260730'),
    ('99000330', 'GC-0330', N'Cristian Eduardo', N'Espinoza Cueva', '19710924', 'M', N'Sector 04', N'Sin seguro', '20260727'),
    ('99000331', 'GC-0331', N'Ana Lucía', N'Ramírez Mendoza', '20151203', 'F', N'Sector 02', N'EsSalud', '20260614'),
    ('99000332', 'GC-0332', N'Karla Vanessa', N'Cárdenas Ortega', '19970707', 'F', N'Sector 03', N'SIS', '20260914'),
    ('99000333', 'GC-0333', N'Héctor Raúl', N'Chávez Medina', '19650126', 'M', N'Sector 05', N'SIS', '20260911'),
    ('99000334', 'GC-0334', N'Héctor Raúl', N'Paredes Becerra', '20090506', 'M', N'Sector 01', N'SIS', '20260625'),
    ('99000335', 'GC-0335', N'Rocío del Pilar', N'Becerra León', '20141120', 'F', N'Sector 03', N'SIS', '20260607'),
    ('99000336', 'GC-0336', N'Manuel Enrique', N'Alfaro Cárdenas', '20070407', 'M', N'Sector 04', N'SIS', '20260613'),
    ('99000337', 'GC-0337', N'Víctor Hugo', N'Huamán Figueroa', '19860123', 'M', N'Sector 05', N'SIS', '20260923'),
    ('99000338', 'GC-0338', N'Mónica Cecilia', N'Valverde Sánchez', '20000817', 'F', N'Sector 05', N'SIS', '20260807'),
    ('99000339', 'GC-0339', N'Diana Carolina', N'Ortega Navarro', '20210331', 'F', N'Sector 02', N'SIS', '20260816'),
    ('99000340', 'GC-0340', N'Sergio Martín', N'Aguilar Castillo', '19740131', 'M', N'Sector 02', N'SIS', '20260820'),
    ('99000341', 'GC-0341', N'Andrea Victoria', N'Rodríguez Mendoza', '20190227', 'F', N'Sector 05', N'SIS', '20260614'),
    ('99000342', 'GC-0342', N'Jorge Luis', N'García Rodríguez', '20140625', 'M', N'Sector 04', N'SIS', '20260623'),
    ('99000343', 'GC-0343', N'Daniela Sofía', N'Rojas Paredes', '20090711', 'F', N'Sector 05', N'SIS', '20260907'),
    ('99000344', 'GC-0344', N'Pedro Antonio', N'Ramírez Paredes', '19800313', 'M', N'Sector 01', N'SIS', '20260517'),
    ('99000345', 'GC-0345', N'María Fernanda', N'Alfaro Torres', '20210914', 'F', N'Sector 02', N'SIS', '20260704'),
    ('99000346', 'GC-0346', N'Karla Vanessa', N'Navarro Gutiérrez', '19960319', 'F', N'Sector 04', N'Sin seguro', '20260425'),
    ('99000347', 'GC-0347', N'Diana Carolina', N'Gutiérrez Castillo', '20260319', 'F', N'Sector 01', N'SIS', '20260506'),
    ('99000348', 'GC-0348', N'Alessandra Dayana', N'Becerra Salazar', '20260620', 'F', N'Sector 01', N'Sin seguro', '20260701'),
    ('99000349', 'GC-0349', N'Fernando Javier', N'Herrera Córdova', '20230620', 'M', N'Sector 05', N'SIS', '20260618'),
    ('99000350', 'GC-0350', N'Claudia Beatriz', N'Reyes Torres', '20031213', 'F', N'Sector 05', N'Sin seguro', '20260916'),
    ('99000351', 'GC-0351', N'Manuel Enrique', N'Pérez García', '20021209', 'M', N'Sector 03', N'SIS', '20260822'),
    ('99000352', 'GC-0352', N'Karla Vanessa', N'Campos Valverde', '19490623', 'F', N'Sector 01', N'SIS', '20260425'),
    ('99000353', 'GC-0353', N'Juan Diego', N'Acosta Quispe', '20170313', 'M', N'Sector 02', N'SIS', '20260908'),
    ('99000354', 'GC-0354', N'Noelia Alexandra', N'Reyes Villanueva', '20250626', 'F', N'Sector 04', N'SIS', '20260424'),
    ('99000355', 'GC-0355', N'Rosa Elena', N'Villanueva Zavaleta', '19770804', 'F', N'Sector 05', N'SIS', '20260712'),
    ('99000356', 'GC-0356', N'Kevin Esteban', N'Ramos Quispe', '20180131', 'M', N'Sector 05', N'SIS', '20260607'),
    ('99000357', 'GC-0357', N'Fiorella Nicole', N'Torres Paredes', '19691204', 'F', N'Sector 02', N'Sin seguro', '20260512'),
    ('99000358', 'GC-0358', N'Roberto Daniel', N'Herrera Quispe', '19400106', 'M', N'Sector 04', N'SIS', '20260718'),
    ('99000359', 'GC-0359', N'Rosa Elena', N'León López', '19380524', 'F', N'Sector 04', N'SIS', '20260405'),
    ('99000360', 'GC-0360', N'Héctor Raúl', N'Córdova Medina', '20250929', 'M', N'Sector 03', N'SIS', '20260717'),
    ('99000361', 'GC-0361', N'César Augusto', N'Paredes Benites', '20260523', 'M', N'Sector 01', N'SIS', '20260605'),
    ('99000362', 'GC-0362', N'Jazmín Guadalupe', N'Mendoza Salazar', '20091018', 'F', N'Sector 02', N'SIS', '20260510'),
    ('99000363', 'GC-0363', N'Cristian Eduardo', N'Córdova Silva', '19710627', 'M', N'Sector 05', N'SIS', '20260519'),
    ('99000364', 'GC-0364', N'Esther Mariana', N'Castillo Morales', '20050830', 'F', N'Sector 01', N'SIS', '20260925'),
    ('99000365', 'GC-0365', N'Daniela Sofía', N'Aguilar Castillo', '19780205', 'F', N'Sector 03', N'Sin seguro', '20260627'),
    ('99000366', 'GC-0366', N'Julio César', N'Ramírez Cárdenas', '19910725', 'M', N'Sector 01', N'SIS', '20260625'),
    ('99000367', 'GC-0367', N'Fiorella Nicole', N'Zavaleta Navarro', '20210512', 'F', N'Sector 04', N'Sin seguro', '20260912'),
    ('99000368', 'GC-0368', N'Luis Alberto', N'Becerra Ramírez', '20110208', 'M', N'Sector 03', N'SIS', '20260726'),
    ('99000369', 'GC-0369', N'Julio César', N'Córdova Navarro', '20070830', 'M', N'Sector 02', N'SIS', '20260710'),
    ('99000370', 'GC-0370', N'Gabriela Estefanía', N'Zavaleta León', '19751212', 'F', N'Sector 03', N'SIS', '20260501'),
    ('99000371', 'GC-0371', N'Andrés Felipe', N'Castillo Flores', '20131020', 'M', N'Sector 02', N'SIS', '20260920'),
    ('99000372', 'GC-0372', N'Brayan Jesús', N'Ponce Valverde', '20090411', 'M', N'Sector 02', N'SIS', '20260801'),
    ('99000373', 'GC-0373', N'Renato Sebastián', N'Palacios Espinoza', '19570327', 'M', N'Sector 04', N'SIS', '20260627'),
    ('99000374', 'GC-0374', N'Carmen Rosa', N'Paredes Torres', '20251117', 'F', N'Sector 05', N'Sin seguro', '20260729'),
    ('99000375', 'GC-0375', N'Claudia Beatriz', N'Figueroa Mendoza', '19910929', 'F', N'Sector 02', N'SIS', '20260705'),
    ('99000376', 'GC-0376', N'Luis Alberto', N'Chávez Quispe', '20201103', 'M', N'Sector 04', N'SIS', '20260711'),
    ('99000377', 'GC-0377', N'Mónica Cecilia', N'Díaz Campos', '20161208', 'F', N'Sector 04', N'SIS', '20260409'),
    ('99000378', 'GC-0378', N'Noelia Alexandra', N'Alvarado Vásquez', '19790829', 'F', N'Sector 05', N'SIS', '20260702'),
    ('99000379', 'GC-0379', N'Carmen Rosa', N'Campos Morales', '19720626', 'F', N'Sector 03', N'SIS', '20260910'),
    ('99000380', 'GC-0380', N'Tatiana Gabriela', N'Torres Paredes', '19980110', 'F', N'Sector 03', N'SIS', '20260614'),
    ('99000381', 'GC-0381', N'Miguel Ángel', N'Ramos Benites', '20110325', 'M', N'Sector 03', N'SIS', '20260508'),
    ('99000382', 'GC-0382', N'Yessenia Milagros', N'Becerra Navarro', '19730509', 'F', N'Sector 02', N'SIS', '20260408'),
    ('99000383', 'GC-0383', N'Andrea Victoria', N'Salazar Cárdenas', '19620612', 'F', N'Sector 02', N'EsSalud', '20260913'),
    ('99000384', 'GC-0384', N'Brenda Aylin', N'López Cárdenas', '20030409', 'F', N'Sector 03', N'SIS', '20260722'),
    ('99000385', 'GC-0385', N'Mónica Cecilia', N'Sánchez Cabrera', '20240804', 'F', N'Sector 01', N'SIS', '20260701'),
    ('99000386', 'GC-0386', N'Brenda Aylin', N'Mendoza Huamán', '20130121', 'F', N'Sector 05', N'SIS', '20260403'),
    ('99000387', 'GC-0387', N'Renato Sebastián', N'Acosta Cruz', '19870220', 'M', N'Sector 04', N'SIS', '20260402'),
    ('99000388', 'GC-0388', N'Martha Lucía', N'Huamán Villanueva', '20010729', 'F', N'Sector 04', N'SIS', '20260601'),
    ('99000389', 'GC-0389', N'Karla Vanessa', N'Díaz Ramos', '20251022', 'F', N'Sector 05', N'SIS', '20260910'),
    ('99000390', 'GC-0390', N'Héctor Raúl', N'Córdova Vargas', '20260413', 'M', N'Sector 04', N'SIS', '20260711'),
    ('99000391', 'GC-0391', N'Luis Alberto', N'Sánchez Gutiérrez', '20010116', 'M', N'Sector 05', N'SIS', '20260501'),
    ('99000392', 'GC-0392', N'Tatiana Gabriela', N'Campos Herrera', '19990325', 'F', N'Sector 04', N'SIS', '20260403'),
    ('99000393', 'GC-0393', N'Noelia Alexandra', N'Aguilar López', '19740217', 'F', N'Sector 03', N'SIS', '20260707'),
    ('99000394', 'GC-0394', N'Miguel Ángel', N'León Montalvo', '19830920', 'M', N'Sector 02', N'SIS', '20260730'),
    ('99000395', 'GC-0395', N'Lucía Isabel', N'Zamora Cabrera', '19690807', 'F', N'Sector 02', N'SIS', '20260807'),
    ('99000396', 'GC-0396', N'Alessandra Dayana', N'Huamán Ponce', '19930729', 'F', N'Sector 05', N'SIS', '20260809'),
    ('99000397', 'GC-0397', N'Ana Lucía', N'Gutiérrez Pérez', '19601219', 'F', N'Sector 01', N'SIS', '20260913'),
    ('99000398', 'GC-0398', N'José Manuel', N'Villanueva León', '20260401', 'M', N'Sector 05', N'SIS', '20260926'),
    ('99000399', 'GC-0399', N'Franco Nicolás', N'Ortega Medina', '20150726', 'M', N'Sector 02', N'SIS', '20260609'),
    ('99000400', 'GC-0400', N'Tatiana Gabriela', N'Vásquez Cueva', '19940201', 'F', N'Sector 01', N'SIS', '20260519')
) AS v(DNI, CodigoPaciente, Nombres, Apellidos, FechaNacimiento, Sexo,
       SectorResidencia, TipoSeguro, FechaRegistro)
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.Pacientes AS p
    WHERE p.DNI = v.DNI OR p.CodigoPaciente = v.CodigoPaciente
);
GO

-- 4. CAMPO DE CONTACTO PARA SEGUIMIENTO DE SEGUNDAS CITAS.
-- Si ya existen 400 pacientes creados con el archivo anterior,
-- esta sección incorpora el teléfono SIN eliminarlos ni modificar su DNI.
-- Formato peruano de celular: 9 dígitos que comienzan con 9.
-- IMPORTANTE: los teléfonos son ficticios y NO deben utilizarse para llamadas reales.
IF COL_LENGTH(N'dbo.Pacientes', N'TelefonoContacto') IS NULL
BEGIN
    ALTER TABLE dbo.Pacientes ADD TelefonoContacto CHAR(9) NULL;
END;
GO

-- Se completa únicamente donde el teléfono aún no se ha registrado.
-- GC-0001 => 900000001, GC-0400 => 900000400.
UPDATE dbo.Pacientes
   SET TelefonoContacto = '9' + RIGHT('00000000' +
       CAST(TRY_CONVERT(INT, RIGHT(CodigoPaciente, 4)) AS VARCHAR(8)), 8)
 WHERE TelefonoContacto IS NULL;
GO

-- La columna será obligatoria una vez completados los datos de ejemplo.
IF EXISTS (SELECT 1 FROM dbo.Pacientes WHERE TelefonoContacto IS NULL)
    THROW 50003, 'Quedaron pacientes sin telefono; revisar sus codigos antes de continuar.', 1;
GO

ALTER TABLE dbo.Pacientes ALTER COLUMN TelefonoContacto CHAR(9) NOT NULL;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.Pacientes')
      AND name = N'CK_Pacientes_Telefono'
)
BEGIN
    ALTER TABLE dbo.Pacientes ADD CONSTRAINT CK_Pacientes_Telefono
    CHECK (TelefonoContacto LIKE '9[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]');
END;
GO

-- 5. VISTA PARA POWER BI: edad al 30/09/2026 y grupo etario.
CREATE OR ALTER VIEW dbo.vw_PacientesBI
AS
SELECT
    p.DNI,
    p.CodigoPaciente,
    p.TelefonoContacto,
    p.Nombres,
    p.Apellidos,
    p.FechaNacimiento,
    p.Sexo,
    p.SectorResidencia,
    p.TipoSeguro,
    p.FechaRegistro,
    e.EdadAlCierre,
    CASE
        WHEN e.EdadAlCierre BETWEEN 0 AND 5 THEN N'00-05 años'
        WHEN e.EdadAlCierre BETWEEN 6 AND 11 THEN N'06-11 años'
        WHEN e.EdadAlCierre BETWEEN 12 AND 17 THEN N'12-17 años'
        WHEN e.EdadAlCierre BETWEEN 18 AND 29 THEN N'18-29 años'
        WHEN e.EdadAlCierre BETWEEN 30 AND 59 THEN N'30-59 años'
        ELSE N'60+ años'
    END AS GrupoEtario
FROM dbo.Pacientes AS p
CROSS APPLY
(
    SELECT
        DATEDIFF(YEAR, p.FechaNacimiento, CONVERT(DATE, '20260930', 112))
        - CASE WHEN DATEADD(
                YEAR,
                DATEDIFF(YEAR, p.FechaNacimiento, CONVERT(DATE, '20260930', 112)),
                p.FechaNacimiento
            ) > CONVERT(DATE, '20260930', 112)
            THEN 1 ELSE 0 END AS EdadAlCierre
) AS e;
GO

-- 6. CONSULTAS DE VALIDACIÓN.
SELECT COUNT(*) AS TotalPacientes FROM dbo.Pacientes; -- 400
SELECT COUNT(DISTINCT DNI) AS DNI_Diferentes FROM dbo.Pacientes; -- 400
SELECT COUNT(DISTINCT TelefonoContacto) AS TelefonosDistintos FROM dbo.Pacientes; -- 400
SELECT kc.name AS NombreClavePrimaria, c.name AS ColumnaClavePrimaria
FROM sys.key_constraints AS kc
JOIN sys.index_columns AS ic
    ON ic.object_id = kc.parent_object_id AND ic.index_id = kc.unique_index_id
JOIN sys.columns AS c
    ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE kc.parent_object_id = OBJECT_ID(N'dbo.Pacientes') AND kc.type = 'PK'; -- DNI
SELECT Sexo, COUNT(*) AS Total FROM dbo.Pacientes GROUP BY Sexo ORDER BY Sexo;
SELECT TOP (10) DNI, Nombres, Apellidos, TelefonoContacto, Sexo, FechaRegistro
FROM dbo.vw_PacientesBI ORDER BY CodigoPaciente;
GO
