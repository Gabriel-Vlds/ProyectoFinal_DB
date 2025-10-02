CREATE DATABASE IF NOT EXISTS proyectofinal;
USE proyectofinal;

-- Tabla Cliente
CREATE TABLE IF NOT EXISTS Cliente (
    id_cliente INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    ap_paterno VARCHAR(50) NOT NULL,
    ap_materno VARCHAR(50),
    telefono VARCHAR(15) NOT NULL UNIQUE,
    email VARCHAR(100)
);

-- Tabla Empleado
CREATE TABLE IF NOT EXISTS Empleado (
    id_empleado INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    ap_paterno VARCHAR(50) NOT NULL,
    ap_materno VARCHAR(50),
    telefono VARCHAR(15),
    email VARCHAR(100)
);

-- Tabla Producto
CREATE TABLE IF NOT EXISTS Producto (
    id_producto INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion VARCHAR(255),
    precio_venta DECIMAL(10, 2) NOT NULL
);

-- Tabla Pedido
CREATE TABLE IF NOT EXISTS Pedido (
    id_pedido INT AUTO_INCREMENT PRIMARY KEY,
    telefono_cliente VARCHAR(15) NOT NULL, -- Número de teléfono del cliente
    id_empleado INT NOT NULL, -- ID del empleado que realiza el pedido
    fecha_pedido DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    sucursal VARCHAR(50) NOT NULL, -- Sucursal donde se realiza el pedido
    estado VARCHAR(20) NOT NULL DEFAULT 'pendiente', -- Estado del pedido
    total DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    FOREIGN KEY (id_empleado) REFERENCES Empleado(id_empleado)
    );
    
    -- Tabla DetallePedido
CREATE TABLE IF NOT EXISTS DetallePedido (
    id_detalle INT AUTO_INCREMENT PRIMARY KEY,
    id_pedido INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL,
    precio_unitario DECIMAL(10, 2) NOT NULL,
    subtotal DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (id_pedido) REFERENCES Pedido(id_pedido),
    FOREIGN KEY (id_producto) REFERENCES Producto(id_producto)
);

-- Tabla Ingrediente
CREATE TABLE IF NOT EXISTS Ingrediente (
    id_ingrediente INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    unidad_medida VARCHAR(20) NOT NULL,
    stock_actual INT NOT NULL DEFAULT 0,
    stock_minimo INT NOT NULL DEFAULT 0,
    precio_unitario DECIMAL(10, 2) NOT NULL,
    id_proveedor INT NOT NULL
);

-- Tabla Proveedor
CREATE TABLE IF NOT EXISTS Proveedor (
    id_proveedor INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    telefono VARCHAR(15),
    email VARCHAR(100)
);

-- Insertar datos iniciales en Producto
INSERT INTO Producto (nombre, descripcion, precio_venta)
VALUES
('Rollo de Canela', 'Rollo glaseado con canela', 45.00),
('Brownie', 'Brownie de chocolate amargo', 35.00),
('Galletas de Vainilla', 'Galletas crujientes de vainilla', 25.00),
('Galleta Chispas Choc', 'Galleta con chispas de chocolate', 28.00),
('Cuernito Dulce', 'Pan dulce glaseado', 22.00);

-- Insertar datos iniciales en Empleado
INSERT INTO Empleado (nombre, ap_paterno, ap_materno, telefono, email)
VALUES
('Juan', 'Pérez', 'Gómez', '1234567890', 'juan.perez@example.com'),
('Ana', 'López', 'Martínez', '0987654321', 'ana.lopez@example.com');

-- Insertar datos iniciales en Proveedor
INSERT INTO Proveedor (nombre, telefono, email)
VALUES
('Proveedor A', '1112223333', 'proveedorA@example.com'),
('Proveedor B', '4445556666', 'proveedorB@example.com');

DELIMITER $$

CREATE PROCEDURE sp_confirmar_pedido(IN pedido_id INT)
BEGIN
    -- Declarar una variable para almacenar el total
    DECLARE total DECIMAL(10, 2);

    -- Calcular el total del pedido sumando los subtotales de los productos
    SELECT SUM(subtotal)
    INTO total
    FROM DetallePedido
    WHERE id_pedido = pedido_id;

    -- Actualizar el total en la tabla Pedido
    UPDATE Pedido
    SET total = total, estado = 'confirmado'
    WHERE id_pedido = pedido_id;
END$$

INSERT INTO Ingrediente (nombre, unidad_medida, stock_actual, stock_minimo, precio_unitario, id_proveedor)
VALUES
('Harina', 'kg', 100, 20, 0.50, 1),
('Azúcar', 'kg', 50, 10, 0.30, 1),
('Chocolate', 'kg', 30, 5, 2.00, 2),
('Mantequilla', 'kg', 40, 10, 1.50, 1),
('Huevos', 'unidad', 200, 50, 0.10, 2);

