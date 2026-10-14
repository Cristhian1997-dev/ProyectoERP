USE ERP_Corporativo;

CREATE OR ALTER PROCEDURE inv.usp_CrearProducto
    @IdCategoria INT,
    @SKU VARCHAR(50),
    @Descripcion VARCHAR(200),
    @PrecioVentaBase DECIMAL(12,2),
    @ManejaLote BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY

        BEGIN TRAN;

        -- Validar categoría existente
        IF NOT EXISTS (
            SELECT 1
            FROM dbo.inv_Categorias
            WHERE IdCategoria = @IdCategoria
        )
        BEGIN
            THROW 51001,
                'La categoría indicada no existe.',
                1;
        END;


        -- Validar SKU
        IF NULLIF(LTRIM(RTRIM(@SKU)), '') IS NULL
        BEGIN
            THROW 51002,
                'El SKU del producto es obligatorio.',
                1;
        END;


        -- Evitar SKU duplicado
        IF EXISTS (
            SELECT 1
            FROM dbo.inv_Productos
            WHERE SKU = @SKU
        )
        BEGIN
            THROW 51003,
                'Ya existe un producto con el SKU indicado.',
                1;
        END;


        -- Validar descripción
        IF NULLIF(LTRIM(RTRIM(@Descripcion)), '') IS NULL
        BEGIN
            THROW 51004,
                'La descripción del producto es obligatoria.',
                1;
        END;


        -- Validar precio
        IF @PrecioVentaBase <= 0
        BEGIN
            THROW 51005,
                'El precio de venta debe ser estrictamente mayor a cero.',
                1;
        END;


        -- Inserción encapsulada
        INSERT INTO dbo.inv_Productos (
            IdCategoria,
            SKU,
            Descripcion,
            PrecioVentaBase,
            ManejaLote
        )
        VALUES (
            @IdCategoria,
            @SKU,
            @Descripcion,
            @PrecioVentaBase,
            @ManejaLote
        );


        DECLARE @IdProductoCreado INT =
            CAST(SCOPE_IDENTITY() AS INT);


        COMMIT TRAN;


        SELECT
            @IdProductoCreado AS IdProducto,
            @SKU AS SKU,
            'Producto creado correctamente mediante Stored Procedure.'
                AS Mensaje;

    END TRY

    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;

        THROW;

    END CATCH
END;

-- Store Procedure para proveedores
CREATE OR ALTER PROCEDURE inv.usp_CrearProveedor
    @NIT VARCHAR(20),
    @RazonSocial VARCHAR(150),
    @DiasCredito INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY

        BEGIN TRAN;


        -- Validar NIT
        IF NULLIF(LTRIM(RTRIM(@NIT)), '') IS NULL
        BEGIN
            THROW 51010,
                'El NIT del proveedor es obligatorio.',
                1;
        END;


        -- Evitar proveedores duplicados por NIT
        IF EXISTS (
            SELECT 1
            FROM dbo.inv_Proveedores
            WHERE NIT = @NIT
        )
        BEGIN
            THROW 51011,
                'Ya existe un proveedor registrado con este NIT.',
                1;
        END;


        -- Validar razón social
        IF NULLIF(LTRIM(RTRIM(@RazonSocial)), '') IS NULL
        BEGIN
            THROW 51012,
                'La razón social es obligatoria.',
                1;
        END;


        -- Validar días de crédito
        IF @DiasCredito < 0
        BEGIN
            THROW 51013,
                'Los días de crédito no pueden ser negativos.',
                1;
        END;


        INSERT INTO dbo.inv_Proveedores (
            NIT,
            RazonSocial,
            DiasCredito
        )
        VALUES (
            @NIT,
            @RazonSocial,
            @DiasCredito
        );


        DECLARE @IdProveedorCreado INT =
            CAST(SCOPE_IDENTITY() AS INT);


        COMMIT TRAN;


        SELECT
            @IdProveedorCreado AS IdProveedor,
            @NIT AS NIT,
            'Proveedor creado correctamente mediante Stored Procedure.'
                AS Mensaje;

    END TRY

    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;

        THROW;

    END CATCH
END;

-- Stored Procedure para clientes
CREATE OR ALTER PROCEDURE pos.usp_CrearCliente
    @IdTipoCliente INT,
    @NIT VARCHAR(15) = 'CF',
    @NombreCompleto VARCHAR(150),
    @LimiteCredito DECIMAL(12,2) = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY

        BEGIN TRAN;


        -- Validar tipo de cliente
        IF NOT EXISTS (
            SELECT 1
            FROM dbo.pos_TiposCliente
            WHERE IdTipoCliente = @IdTipoCliente
        )
        BEGIN
            THROW 51020,
                'El tipo de cliente indicado no existe.',
                1;
        END;


        -- Validar nombre
        IF NULLIF(LTRIM(RTRIM(@NombreCompleto)), '') IS NULL
        BEGIN
            THROW 51021,
                'El nombre del cliente es obligatorio.',
                1;
        END;


        -- Validar crédito
        IF @LimiteCredito < 0
        BEGIN
            THROW 51022,
                'El límite de crédito no puede ser negativo.',
                1;
        END;


        -- Si no se proporciona NIT usamos CF.
        SET @NIT = COALESCE(
            NULLIF(LTRIM(RTRIM(@NIT)), ''),
            'CF'
        );


        INSERT INTO dbo.pos_Clientes (
            IdTipoCliente,
            NIT,
            NombreCompleto,
            LimiteCredito
        )
        VALUES (
            @IdTipoCliente,
            @NIT,
            @NombreCompleto,
            @LimiteCredito
        );


        DECLARE @IdClienteCreado INT =
            CAST(SCOPE_IDENTITY() AS INT);


        COMMIT TRAN;


        SELECT
            @IdClienteCreado AS IdCliente,
            @NombreCompleto AS Cliente,
            'Cliente creado correctamente mediante Stored Procedure.'
                AS Mensaje;

    END TRY

    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;

        THROW;

    END CATCH
END;

--Verificamos que los 3 Stored Procedure existen
SELECT
    SCHEMA_NAME(p.schema_id) AS Esquema,
    p.name AS Procedimiento,
    p.create_date AS FechaCreacion,
    p.modify_date AS UltimaModificacion

FROM sys.procedures p

WHERE p.name IN (
    'usp_CrearProducto',
    'usp_CrearProveedor',
    'usp_CrearCliente'
)

ORDER BY
    Esquema,
    Procedimiento;

-- Probamos usp_CrearProductos
DECLARE @IdCategoria INT;

SELECT @IdCategoria = IdCategoria
FROM dbo.inv_Categorias
WHERE NombreCategoria = 'Ferretería';


EXEC inv.usp_CrearProducto
    @IdCategoria = @IdCategoria,
    @SKU = 'HERR-099',
    @Descripcion = 'Taladro Percutor',
    @PrecioVentaBase = 850.00,
    @ManejaLote = 0;

-- Probamos usp_CrearProveedor
EXEC inv.usp_CrearProveedor
    @NIT = '8888888-8',
    @RazonSocial = 'Herramientas Industriales S.A.',
    @DiasCredito = 30;

-- Probanos usp_CrearCliente
DECLARE @IdTipoCliente INT;

SELECT TOP (1)
    @IdTipoCliente = IdTipoCliente
FROM dbo.pos_TiposCliente
WHERE NombreTipo = 'Consumidor Final';


EXEC pos.usp_CrearCliente
    @IdTipoCliente = @IdTipoCliente,
    @NIT = '24681357',
    @NombreCompleto = 'Cliente Fase 4 S.A.',
    @LimiteCredito = 10000.00;

-- Verificación final
SELECT
    IdProducto,
    SKU,
    Descripcion,
    PrecioVentaBase,
    StockActual,
    Activo
FROM dbo.inv_Productos
WHERE SKU = 'HERR-099';


SELECT
    IdProveedor,
    NIT,
    RazonSocial,
    DiasCredito
FROM dbo.inv_Proveedores
WHERE NIT = '8888888-8';


SELECT
    IdCliente,
    NIT,
    NombreCompleto,
    LimiteCredito
FROM dbo.pos_Clientes
WHERE NIT = '24681357';

-- Preparando la columna TotalNeto
-- Una vista indexada con SUM necesita trabajar
-- con una expresión no nullable.
UPDATE dbo.pos_VentasMaster
SET TotalNeto = 0
WHERE TotalNeto IS NULL;

-- 1. Eliminar temporalmente la columna calculada
ALTER TABLE dbo.pos_VentasMaster
DROP COLUMN GranTotal;

-- 2. Convertir TotalNeto en NOT NULL
ALTER TABLE dbo.pos_VentasMaster
ALTER COLUMN TotalNeto DECIMAL(12,2) NOT NULL;

-- 3. Volver a crear GranTotal como columna calculada persistida
ALTER TABLE dbo.pos_VentasMaster
ADD GranTotal AS
    ([TotalNeto] - [TotalDescuentos]) PERSISTED;

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

--Crear la vista con SCHEMABINDING
IF OBJECT_ID('pos.vw_ResumenVentasPorDepto', 'V') IS NOT NULL
BEGIN
    DROP VIEW pos.vw_ResumenVentasPorDepto;
END;

CREATE VIEW pos.vw_ResumenVentasPorDepto
WITH SCHEMABINDING
AS

SELECT
    d.IdDepto,
    d.NombreDepto,

    COUNT_BIG(*) AS CantidadTransacciones,

    SUM(v.TotalNeto) AS SumaTotalNeto

FROM dbo.pos_VentasMaster AS v

INNER JOIN dbo.glb_Sucursales AS s
    ON v.IdSucursal = s.IdSucursal

INNER JOIN dbo.glb_Municipios AS m
    ON s.IdMunicipio = m.IdMunicipio

INNER JOIN dbo.glb_Departamentos AS d
    ON m.IdDepto = d.IdDepto

GROUP BY
    d.IdDepto,
    d.NombreDepto;

SELECT
    SCHEMA_NAME(schema_id) AS Esquema,
    name AS Vista
FROM sys.views
WHERE name = 'vw_ResumenVentasPorDepto';

-- Creamos el índice clúster único
CREATE UNIQUE CLUSTERED INDEX UQ_IDX_VentasDepto
ON pos.vw_ResumenVentasPorDepto (IdDepto);

SELECT
    OBJECT_SCHEMA_NAME(i.object_id) AS Esquema,
    OBJECT_NAME(i.object_id) AS Vista,
    i.name AS Indice,
    i.type_desc AS TipoIndice,
    i.is_unique AS EsUnico

FROM sys.indexes AS i

WHERE i.object_id =
      OBJECT_ID('pos.vw_ResumenVentasPorDepto')

  AND i.index_id > 0;
  
SELECT
    IdDepto,
    NombreDepto,
    CantidadTransacciones,
    SumaTotalNeto

FROM pos.vw_ResumenVentasPorDepto
WITH (NOEXPAND);