-- Autor: Cristhian Mucun | Carne: 2290-17-17851
-- ==============================================
USE master;

--Si la base no existe, no intenta eliminarla.
IF DB_ID('ERP_Corporativo') IS NOT NULL --Encuentra una base llamada ERP_Corporativo, entonces
	DROP DATABASE ERP_Corporativo; --elimina completamente la base de datos.

-- Simulamos la creacion de Filegroups para el particionamiento físico
CREATE DATABASE ERP_Corporativo;
USE ERP_Corporativo;

--SEGURIDAD y SCHEMAS
CREATE LOGIN ErpAdmin WITH PASSWORD = 'Sys@ErpPassword2026!';
CREATE USER ErpAdmin FOR LOGIN ErpAdmin;
ALTER ROLE db_
owner ADD MEMBER ErpAdmin;


CREATE SCHEMA gbl; -- Globales y Geografía
CREATE SCHEMA hr; -- Recursos Humanos y Nómina
CREATE SCHEMA inv; -- Inventarios y Cadena de Suministros
CREATE SCHEMA pos; -- Punto de Venta y Clientes
CREATE SCHEMA cont; -- Contabilidad y Finanzas

-- PARTICIONAMIENTO
CREATE PARTITION FUNCTION pf_DepartamentosGT (INT)
AS RANGE LEFT FOR VALUES
(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22);

CREATE PARTITION SCHEME ps_DepartamentosGT
AS PARTITION pf_DepartamentosGT
ALL TO ([PRIMARY]);

-- SECUENCIAS
CREATE SEQUENCE cont.Seq_PartidasContables
START WITH 1
INCREMENT BY 1;

CREATE SEQUENCE pos.Seq_Facturas
START WITH 1
INCREMENT BY 1;

--DOMINIO GLOBAL
CREATE TABLE glb_Paises (
    IdPais INT IDENTITY(1,1) PRIMARY KEY,
    NombrePais VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE glb_Departamentos (
    IdDepto INT IDENTITY(1,1) PRIMARY KEY,
    IdPais INT NOT NULL REFERENCES glb_Paises(IdPais),
    NombreDepto VARCHAR(100) NOT NULL
);

CREATE TABLE glb_Municipios (
    IdMunicipio INT IDENTITY(1,1) PRIMARY KEY,
    IdDepto INT NOT NULL REFERENCES glb_Departamentos(IdDepto),
    NombreMunicipio VARCHAR(100) NOT NULL
);

CREATE TABLE glb_Monedas (
    IdMoneda INT IDENTITY(1,1) PRIMARY KEY,
    CodigoISO CHAR(3) NOT NULL UNIQUE,
    NombreMoneda VARCHAR(50) NOT NULL,
    TasaCambioBase DECIMAL(10,4) NOT NULL DEFAULT 1.0000
);

CREATE TABLE glb_Empresas (
    IdEmpresa INT IDENTITY(1,1) PRIMARY KEY,
    NIT VARCHAR(20) NOT NULL UNIQUE,
    RazonSocial VARCHAR(150) NOT NULL,
    IdMonedaLocal INT NOT NULL REFERENCES glb_Monedas(IdMoneda),
    Activo BIT DEFAULT 1
);

CREATE TABLE glb_Sucursales (
    IdSucursal INT IDENTITY(1,1) PRIMARY KEY,
    IdEmpresa INT NOT NULL REFERENCES glb_Empresas(IdEmpresa),
    IdMunicipio INT NOT NULL REFERENCES glb_Municipios(IdMunicipio),
    NombreSucursal VARCHAR(100) NOT NULL,
    EsMatriz BIT DEFAULT 0
);

-- DOMINIO RECURSOS HUMANOS
CREATE TABLE hr_DepartamentosEmpresa (
    IdDeptoEmpresa INT IDENTITY(1,1) PRIMARY KEY,
    NombreDepartamento VARCHAR(100) NOT NULL
);

CREATE TABLE hr_Puestos (
    IdPuesto INT IDENTITY(1,1) PRIMARY KEY,
    NombrePuesto VARCHAR(100) NOT NULL,
    IdPuestoJefe INT NULL,
    SalarioBase DECIMAL(12,2) NOT NULL CHECK (SalarioBase > 0),

    CONSTRAINT FK_Puesto_Jefatura
    FOREIGN KEY (IdPuestoJefe)
    REFERENCES hr_Puestos(IdPuesto)
);

CREATE TABLE hr_Empleados (
    IdEmpleado INT IDENTITY(1,1) PRIMARY KEY,
    IdSucursal INT NOT NULL REFERENCES glb_Sucursales(IdSucursal),
    IdDeptoEmpresa INT NOT NULL
        REFERENCES hr_DepartamentosEmpresa(IdDeptoEmpresa),
    IdPuesto INT NOT NULL REFERENCES hr_Puestos(IdPuesto),
    DPI VARCHAR(15) NOT NULL UNIQUE,
    NombreCompleto VARCHAR(150) NOT NULL,
    FechaNacimiento DATE NOT NULL,
    FechaIngreso DATE DEFAULT GETDATE(),
    Estado VARCHAR(20) DEFAULT 'Activo'
        CHECK (Estado IN ('Activo', 'Suspendido', 'Baja'))
);

CREATE TABLE hr_PlanillaMaster (
    IdPlanilla INT IDENTITY(1,1) PRIMARY KEY,
    IdEmpresa INT NOT NULL REFERENCES glb_Empresas(IdEmpresa),
    Mes INT CHECK (Mes BETWEEN 1 AND 12),
    Anio INT CHECK (Anio > 2000),
    TotalPagado DECIMAL(18,2) DEFAULT 0,
    FechaProceso DATETIME DEFAULT GETDATE(),
    Procesada BIT DEFAULT 0
);

CREATE TABLE hr_PlanillaDetalle (
    IdDetalle INT IDENTITY(1,1) PRIMARY KEY,
    IdPlanilla INT NOT NULL REFERENCES hr_PlanillaMaster(IdPlanilla),
    IdEmpleado INT NOT NULL REFERENCES hr_Empleados(IdEmpleado),
    DiasTrabajados INT NOT NULL DEFAULT 30,
    SalarioDevengado DECIMAL(12,2) NOT NULL,
    Bonificaciones DECIMAL(12,2) DEFAULT 0,
    Descuentos DECIMAL(12,2) DEFAULT 0,
    LiquidoRecibir AS
        ((SalarioDevengado + Bonificaciones) - Descuentos) PERSISTED
);

--DOMINIO CONTABILIDAD
CREATE TABLE cont_Nomenclatura (
    IdCuenta INT IDENTITY(1,1) PRIMARY KEY,
    IdEmpresa INT NOT NULL REFERENCES glb_Empresas(IdEmpresa),
    CodigoCuenta VARCHAR(20) NOT NULL,
    NombreCuenta VARCHAR(150) NOT NULL,
    IdCuentaPadre INT NULL REFERENCES cont_Nomenclatura(IdCuenta),
    TipoCuenta VARCHAR(20)
        CHECK (TipoCuenta IN ('Activo', 'Pasivo', 'Capital', 'Ingreso', 'Gasto')),
    AceptaMovimientos BIT DEFAULT 1
);

CREATE TABLE cont_PartidasMaster (
    IdPartida INT PRIMARY KEY
        DEFAULT NEXT VALUE FOR cont.Seq_PartidasContables,
    IdEmpresa INT NOT NULL REFERENCES glb_Empresas(IdEmpresa),
    IdSucursal INT NOT NULL REFERENCES glb_Sucursales(IdSucursal),
    FechaContable DATE DEFAULT GETDATE(),
    Concepto VARCHAR(255) NOT NULL,
    TotalDebe DECIMAL(18,2) DEFAULT 0,
    TotalHaber DECIMAL(18,2) DEFAULT 0,
    Estado VARCHAR(20) DEFAULT 'Cuadrada'
);

CREATE TABLE cont_PartidasDetalle (
    IdDetalle INT IDENTITY(1,1) PRIMARY KEY,
    IdPartida INT NOT NULL
        REFERENCES cont_PartidasMaster(IdPartida)
        ON DELETE CASCADE,
    IdCuenta INT NOT NULL
        REFERENCES cont_Nomenclatura(IdCuenta),
    Debe DECIMAL(18,2) DEFAULT 0,
    Haber DECIMAL(18,2) DEFAULT 0,

    CONSTRAINT CK_DebeHaber
    CHECK (
        Debe >= 0
        AND Haber >= 0
        AND (Debe > 0 OR Haber > 0)
    )
);

--DOMINIO INVENTARIOS
CREATE TABLE inv_Proveedores (
    IdProveedor INT IDENTITY(1,1) PRIMARY KEY,
    NIT VARCHAR(20) NOT NULL UNIQUE,
    RazonSocial VARCHAR(150) NOT NULL,
    DiasCredito INT DEFAULT 0
);

CREATE TABLE inv_Bodegas (
    IdBodega INT IDENTITY(1,1) PRIMARY KEY,
    IdSucursal INT NOT NULL REFERENCES glb_Sucursales(IdSucursal),
    NombreBodega VARCHAR(100) NOT NULL
);

CREATE TABLE inv_Categorias (
    IdCategoria INT IDENTITY(1,1) PRIMARY KEY,
    NombreCategoria VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE inv_Productos (
    IdProducto INT IDENTITY(1,1) PRIMARY KEY,
    IdCategoria INT NOT NULL REFERENCES inv_Categorias(IdCategoria),
    SKU VARCHAR(50) NOT NULL UNIQUE,
    Descripcion VARCHAR(200) NOT NULL,
    CostoPromedio DECIMAL(18,4) DEFAULT 0.0000,
    UltimoCosto DECIMAL(18,4) DEFAULT 0.0000,
    PrecioVentaBase DECIMAL(12,2) NOT NULL CHECK (PrecioVentaBase > 0),
    ManejaLote BIT DEFAULT 0,
    Activo BIT DEFAULT 1
);

CREATE TABLE inv_MovimientosMaster (
    IdMovimiento INT IDENTITY(1,1) PRIMARY KEY,
    IdBodega INT NOT NULL REFERENCES inv_Bodegas(IdBodega),
    IdProveedor INT NULL REFERENCES inv_Proveedores(IdProveedor),
    TipoMovimiento VARCHAR(10)
        CHECK (TipoMovimiento IN ('Ingreso', 'Egreso')),
    DocumentoRespaldo VARCHAR(50) NOT NULL,
    FechaMovimiento DATETIME DEFAULT GETDATE()
);

CREATE TABLE inv_MovimientosDetalle (
    IdDetalle INT IDENTITY(1,1) PRIMARY KEY,
    IdMovimiento INT NOT NULL
        REFERENCES inv_MovimientosMaster(IdMovimiento)
        ON DELETE CASCADE,
    IdProducto INT NOT NULL REFERENCES inv_Productos(IdProducto),
    Cantidad DECIMAL(10,2) NOT NULL CHECK (Cantidad > 0),
    CostoUnitario DECIMAL(18,4) NOT NULL CHECK (CostoUnitario >= 0),
    CostoTotalLinea AS (Cantidad * CostoUnitario) PERSISTED
);

--POS y VENTAS
CREATE TABLE pos_TiposCliente (
    IdTipoCliente INT IDENTITY(1,1) PRIMARY KEY,
    NombreTipo VARCHAR(50) NOT NULL,
    PorcentajeDescuento DECIMAL(5,2)
        DEFAULT 0.00
        CHECK (PorcentajeDescuento BETWEEN 0 AND 100)
);

CREATE TABLE pos_Clientes (
    IdCliente INT IDENTITY(1,1) PRIMARY KEY,
    IdTipoCliente INT NOT NULL
        REFERENCES pos_TiposCliente(IdTipoCliente),
    NIT VARCHAR(15) DEFAULT 'CF',
    NombreCompleto VARCHAR(150) NOT NULL,
    LimiteCredito DECIMAL(12,2)
        DEFAULT 0
        CHECK (LimiteCredito >= 0)
);

CREATE TABLE pos_TiposPago (
    IdTipoPago INT IDENTITY(1,1) PRIMARY KEY,
    NombrePago VARCHAR(50) NOT NULL,
    RequiereAutorizacion BIT DEFAULT 0
);

CREATE TABLE pos_VentasMaster (
    IdVenta INT NOT NULL,
    IdDepto INT NOT NULL,
    IdSucursal INT NOT NULL
        REFERENCES glb_Sucursales(IdSucursal),
    IdCliente INT NOT NULL
        REFERENCES pos_Clientes(IdCliente),
    IdEmpleadoCajero INT NOT NULL
        REFERENCES hr_Empleados(IdEmpleado),
    FolioFactura INT
        DEFAULT NEXT VALUE FOR pos.Seq_Facturas,
    FechaVenta DATETIME DEFAULT GETDATE(),
    TotalNeto DECIMAL(12,2)
        DEFAULT 0
        CHECK (TotalNeto >= 0),
    TotalDescuentos DECIMAL(12,2)
        DEFAULT 0,
    GranTotal AS
        (TotalNeto - TotalDescuentos) PERSISTED,
    Estado VARCHAR(20) DEFAULT 'Emitida',

    CONSTRAINT CK_VentasMaster_Descuentos
        CHECK (
            TotalDescuentos >= 0
            AND TotalDescuentos <= TotalNeto
        ),
    CONSTRAINT PK_VentasMaster
        PRIMARY KEY CLUSTERED (IdVenta, IdDepto)

) ON ps_DepartamentosGT(IdDepto);

CREATE TABLE pos_VentasDetalle (
    IdDetalle INT IDENTITY(1,1) PRIMARY KEY,
    IdVenta INT NOT NULL,
    IdDepto INT NOT NULL,
    IdProducto INT NOT NULL
        REFERENCES inv_Productos(IdProducto),
    IdBodega INT NOT NULL
        REFERENCES inv_Bodegas(IdBodega),
    Cantidad INT NOT NULL
        CHECK (Cantidad > 0),
    PrecioUnitario DECIMAL(12,2)
        NOT NULL
        CHECK (PrecioUnitario > 0),
    DescuentoLinea DECIMAL(12,2)
        DEFAULT 0,
    SubTotalLinea AS
        ((Cantidad * PrecioUnitario) - DescuentoLinea) PERSISTED,
    CONSTRAINT CK_VentasDetalle_Descuento
        CHECK (
            DescuentoLinea >= 0
            AND DescuentoLinea <= Cantidad * PrecioUnitario
        ),
    CONSTRAINT FK_VentasDetalle_Master
        FOREIGN KEY (IdVenta, IdDepto)
        REFERENCES pos_VentasMaster(IdVenta, IdDepto)
        ON DELETE CASCADE
);

CREATE TABLE pos_PagosVenta (
    IdPago INT IDENTITY(1,1) PRIMARY KEY,
    IdVenta INT NOT NULL,
    IdDepto INT NOT NULL,
    IdTipoPago INT NOT NULL
        REFERENCES pos_TiposPago(IdTipoPago),
    IdMoneda INT NOT NULL
        REFERENCES glb_Monedas(IdMoneda),
    MontoPagado DECIMAL(12,2)
        NOT NULL
        CHECK (MontoPagado > 0),
    Referencia VARCHAR(100) NULL,
    CONSTRAINT FK_PagosVenta_Master
        FOREIGN KEY (IdVenta, IdDepto)
        REFERENCES pos_VentasMaster(IdVenta, IdDepto)
);
