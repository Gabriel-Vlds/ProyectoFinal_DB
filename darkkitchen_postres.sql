USE proyectofinal;                                  

-- 1) LIMPIEZA SEGURA
SET FOREIGN_KEY_CHECKS = 0;                         -- Apago validación de FKs para borrar sin errores

-- Borro rutinas si existieran
DROP TRIGGER     IF EXISTS tr_detalle_subtotal_bi;  -- Trigger de subtotal (detalle)
DROP TRIGGER     IF EXISTS tr_detalle_no_duplicado; -- Trigger anti-duplicados en detalle
DROP TRIGGER     IF EXISTS tr_seguimiento_cliente;  -- Trigger de seguimiento a clientes
DROP PROCEDURE   IF EXISTS sp_confirmar_pedido;     -- Confirma pedido (stock + total)
DROP PROCEDURE   IF EXISTS sp_marcar_entregado;     -- Marca pedido entregado
DROP PROCEDURE   IF EXISTS sp_ventas_diarias;       -- Ventas por fecha (reporte)
DROP PROCEDURE   IF EXISTS sp_clientes_vigentes_Q1; -- Clientes con compra durante Q1
DROP PROCEDURE   IF EXISTS sp_agregar_cliente;      -- Alta de cliente con “try/catch”
-- DROP FUNCTION IF EXISTS fn_total_pedido;         -- (No usamos función para evitar permisos)

-- Borro tablas (de hijas a padres)
DROP TABLE IF EXISTS SeguimientoCliente;            -- Tabla de seguimiento de clientes (trigger)
DROP TABLE IF EXISTS Entrega;
DROP TABLE IF EXISTS Pago;
DROP TABLE IF EXISTS MetodoPago;
DROP TABLE IF EXISTS DetallePedido;
DROP TABLE IF EXISTS Pedido;
DROP TABLE IF EXISTS Receta;
DROP TABLE IF EXISTS Producto;
DROP TABLE IF EXISTS Ingrediente;
DROP TABLE IF EXISTS Proveedor;
DROP TABLE IF EXISTS Cliente;
DROP TABLE IF EXISTS Empleado;
DROP TABLE IF EXISTS Rol;

SET FOREIGN_KEY_CHECKS = 1;                         -- Vuelvo a activar validación de FKs

-- 2) CREACIÓN DE TABLAS (orientadas a postres)

-- Roles (cajero, repostero, empaquetador, repartidor, supervisor)
CREATE TABLE Rol (
  id_rol INT AUTO_INCREMENT PRIMARY KEY,            -- Identificador del rol
  nombre_rol VARCHAR(50) NOT NULL                   -- Nombre del rol
);

-- Empleados
CREATE TABLE Empleado (
  id_empleado INT AUTO_INCREMENT PRIMARY KEY,       -- Identificador del empleado
  nombre VARCHAR(50) NOT NULL,                      -- Nombre
  ap_paterno VARCHAR(50) NOT NULL,                  -- Apellido paterno
  ap_materno VARCHAR(50) NULL,                      -- Apellido materno (opcional)
  telefono VARCHAR(15) NULL,                        -- Teléfono
  id_rol INT NOT NULL,                              -- Rol (FK)
  CONSTRAINT fk_empleado_rol
    FOREIGN KEY (id_rol) REFERENCES Rol(id_rol)
);

-- Clientes (único por email)
CREATE TABLE Cliente (
  id_cliente INT AUTO_INCREMENT PRIMARY KEY,        -- Identificador del cliente
  nombre VARCHAR(50) NOT NULL,                      -- Nombre
  ap_paterno VARCHAR(50) NOT NULL,                  -- Apellido paterno
  ap_materno VARCHAR(50) NULL,                      -- Apellido materno (opcional)
  telefono VARCHAR(15) NULL,                        -- Teléfono
  email VARCHAR(80) NOT NULL UNIQUE                 -- Email único (restricción de unicidad)
);

-- Proveedores
CREATE TABLE Proveedor (
  id_proveedor INT AUTO_INCREMENT PRIMARY KEY,      -- Identificador del proveedor
  nombre VARCHAR(100) NOT NULL,                     -- Nombre comercial
  telefono VARCHAR(15) NULL,                        -- Teléfono
  email VARCHAR(80) NULL,                           -- Correo
  direccion VARCHAR(255) NULL                       -- Dirección
);

-- Ingredientes (postres)
CREATE TABLE Ingrediente (
  id_ingrediente INT AUTO_INCREMENT PRIMARY KEY,    -- Identificador del ingrediente
  nombre VARCHAR(100) NOT NULL,                     -- Ej. Harina, Azúcar, Canela, Chocolate
  unidad_medida VARCHAR(20) NOT NULL,               -- g, ml, pza
  stock_actual INT NOT NULL DEFAULT 0,              -- Existencia actual
  stock_minimo INT NOT NULL DEFAULT 0,              -- Stock mínimo
  precio_unitario DECIMAL(10,2) NOT NULL DEFAULT 0, -- Costo por unidad
  id_proveedor INT NOT NULL,                        -- Proveedor (FK)
  CONSTRAINT fk_ing_prov FOREIGN KEY (id_proveedor) REFERENCES Proveedor(id_proveedor),
  CONSTRAINT chk_stock_no_neg CHECK (stock_actual >= 0 AND stock_minimo >= 0) -- Evito negativos
);

-- Productos (postres vendidos)
CREATE TABLE Producto (
  id_producto INT AUTO_INCREMENT PRIMARY KEY,       -- Identificador del producto
  nombre VARCHAR(100) NOT NULL,                     -- Ej. Rollo de canela, Brownie, Galletas
  descripcion VARCHAR(255) NULL,                    -- Descripción
  precio_venta DECIMAL(10,2) NOT NULL               -- Precio de venta
);

-- Receta (puente M:N producto–ingrediente)
CREATE TABLE Receta (
  id_producto INT NOT NULL,                         -- Producto
  id_ingrediente INT NOT NULL,                      -- Ingrediente
  cantidad DECIMAL(10,2) NOT NULL,                  -- Cantidad requerida por porción
  PRIMARY KEY (id_producto, id_ingrediente),        -- PK compuesta
  CONSTRAINT fk_rec_prod FOREIGN KEY (id_producto) REFERENCES Producto(id_producto),
  CONSTRAINT fk_rec_ing  FOREIGN KEY (id_ingrediente) REFERENCES Ingrediente(id_ingrediente),
  CONSTRAINT chk_cant_pos CHECK (cantidad > 0)      -- Evito cantidades <= 0
);

-- Pedidos (agrego “canal” para trigger de seguimiento)
CREATE TABLE Pedido (
  id_pedido INT AUTO_INCREMENT PRIMARY KEY,         -- Identificador del pedido
  id_cliente INT NOT NULL,                          -- Cliente (FK)
  id_empleado INT NOT NULL,                         -- Empleado que atiende (FK)
  fecha_pedido DATETIME NOT NULL,                   -- Fecha y hora
  canal ENUM('local','web','app') NOT NULL DEFAULT 'local', -- Canal de venta
  estado ENUM('pendiente','preparando','enviado','entregado','cancelado') NOT NULL DEFAULT 'pendiente',
  total DECIMAL(10,2) NOT NULL DEFAULT 0.00,        -- Total del pedido
  CONSTRAINT fk_ped_cli FOREIGN KEY (id_cliente) REFERENCES Cliente(id_cliente),
  CONSTRAINT fk_ped_emp FOREIGN KEY (id_empleado) REFERENCES Empleado(id_empleado)
);

-- Detalle de pedido (líneas)
CREATE TABLE DetallePedido (
  id_pedido INT NOT NULL,                           -- Pedido (FK)
  id_producto INT NOT NULL,                         -- Producto (FK)
  cantidad INT NOT NULL,                            -- Cantidad
  precio_unitario DECIMAL(10,2) NOT NULL,           -- Precio al momento
  subtotal DECIMAL(10,2) NOT NULL,                  -- cantidad*precio
  PRIMARY KEY (id_pedido, id_producto),             -- Evita duplicar mismo producto dentro del pedido
  CONSTRAINT fk_det_ped FOREIGN KEY (id_pedido) REFERENCES Pedido(id_pedido),
  CONSTRAINT fk_det_prod FOREIGN KEY (id_producto) REFERENCES Producto(id_producto),
  CONSTRAINT chk_cant_pos CHECK (cantidad > 0)      -- Evito cantidades <= 0
);

-- Métodos de pago
CREATE TABLE MetodoPago (
  id_metodo INT AUTO_INCREMENT PRIMARY KEY,         -- Identificador
  nombre_metodo VARCHAR(50) NOT NULL                -- Efectivo, Tarjeta, etc.
);

-- Pagos (1:1 con pedido)
CREATE TABLE Pago (
  id_pago INT AUTO_INCREMENT PRIMARY KEY,           -- Identificador del pago
  id_pedido INT NOT NULL UNIQUE,                    -- Pedido pagado (único)
  id_metodo INT NOT NULL,                           -- Método (FK)
  monto DECIMAL(10,2) NOT NULL,                     -- Monto
  fecha_pago DATETIME NOT NULL,                     -- Fecha del pago
  CONSTRAINT fk_pago_pedido FOREIGN KEY (id_pedido) REFERENCES Pedido(id_pedido),
  CONSTRAINT fk_pago_metodo FOREIGN KEY (id_metodo) REFERENCES MetodoPago(id_metodo)
);

-- Entregas (1:1 con pedido)
CREATE TABLE Entrega (
  id_entrega INT AUTO_INCREMENT PRIMARY KEY,        -- Identificador
  id_pedido INT NOT NULL UNIQUE,                    -- Pedido asociado
  id_empleado_repartidor INT NOT NULL,              -- Repartidor (FK Empleado)
  fecha_salida DATETIME NULL,                       -- Salida
  fecha_entrega DATETIME NULL,                      -- Entrega real
  estatus ENUM('asignada','en_ruta','entregada','fallida') NOT NULL DEFAULT 'asignada',
  tiempo_estimado_min INT NULL,                     -- Min estimados
  tiempo_real_min INT NULL,                         -- Min reales
  CONSTRAINT fk_ent_ped FOREIGN KEY (id_pedido) REFERENCES Pedido(id_pedido),
  CONSTRAINT fk_ent_rep FOREIGN KEY (id_empleado_repartidor) REFERENCES Empleado(id_empleado)
);

-- Seguimiento de clientes (para trigger web/app)
CREATE TABLE SeguimientoCliente (
  id_seguimiento INT AUTO_INCREMENT PRIMARY KEY,    -- Identificador
  id_cliente INT NOT NULL,                          -- Cliente
  id_pedido INT NOT NULL,                           -- Pedido
  canal ENUM('local','web','app') NOT NULL,         -- Canal del pedido
  fecha_hora DATETIME NOT NULL,                     -- Fecha/hora del evento
  CONSTRAINT fk_seg_cli FOREIGN KEY (id_cliente) REFERENCES Cliente(id_cliente),
  CONSTRAINT fk_seg_ped FOREIGN KEY (id_pedido) REFERENCES Pedido(id_pedido)
);

-- 3) TRIGGERS Y PROCEDIMIENTOS

-- Trigger: subtotal del detalle (antes de insertar)
DELIMITER $$
CREATE TRIGGER tr_detalle_subtotal_bi
BEFORE INSERT ON DetallePedido
FOR EACH ROW
BEGIN
  SET NEW.subtotal = NEW.cantidad * NEW.precio_unitario;  -- Calculo el subtotal automáticamente
END$$
DELIMITER ;

-- Trigger: anti-duplicados (mensaje claro). Aunque la PK ya evita duplicado, aquí avisamos.
DELIMITER $$
CREATE TRIGGER tr_detalle_no_duplicado
BEFORE INSERT ON DetallePedido
FOR EACH ROW
BEGIN
  IF EXISTS (SELECT 1 FROM DetallePedido 
             WHERE id_pedido = NEW.id_pedido AND id_producto = NEW.id_producto) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se puede duplicar el mismo producto en el mismo pedido';
  END IF;
END$$
DELIMITER ;

-- Trigger: seguimiento clientes (cuando compra por web o app)
DELIMITER $$
CREATE TRIGGER tr_seguimiento_cliente
AFTER INSERT ON Pedido
FOR EACH ROW
BEGIN
  IF NEW.canal IN ('web','app') THEN
    INSERT INTO SeguimientoCliente (id_cliente, id_pedido, canal, fecha_hora)
    VALUES (NEW.id_cliente, NEW.id_pedido, NEW.canal, NOW());  -- Registro de seguimiento
  END IF;
END$$
DELIMITER ;

-- SP: confirmar pedido (valida stock, descuenta, recalcula total y cambia estado)
DELIMITER $$
CREATE PROCEDURE sp_confirmar_pedido(IN p_id INT)
BEGIN
  -- Validar stock suficiente
  IF EXISTS (
    SELECT 1
    FROM DetallePedido d
    JOIN Receta r  ON r.id_producto = d.id_producto
    JOIN Ingrediente i ON i.id_ingrediente = r.id_ingrediente
    WHERE d.id_pedido = p_id
      AND i.stock_actual < (r.cantidad * d.cantidad)
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock insuficiente para una o más líneas del pedido';
  END IF;

  -- Descontar inventario según receta
  UPDATE Ingrediente i
  JOIN (
    SELECT r.id_ingrediente, SUM(r.cantidad * d.cantidad) AS qty_total
    FROM DetallePedido d
    JOIN Receta r ON r.id_producto = d.id_producto
    WHERE d.id_pedido = p_id
    GROUP BY r.id_ingrediente
  ) x ON x.id_ingrediente = i.id_ingrediente
  SET i.stock_actual = i.stock_actual - x.qty_total;

  -- Recalcular total del pedido SIN función (para evitar permisos)
  UPDATE Pedido p
  JOIN (
    SELECT id_pedido, SUM(subtotal) AS total
    FROM DetallePedido
    WHERE id_pedido = p_id
    GROUP BY id_pedido
  ) t ON t.id_pedido = p.id_pedido
  SET p.total = t.total,
      p.estado = 'preparando'
  WHERE p.id_pedido = p_id;
END$$
DELIMITER ;

-- SP: marcar entregado (y calcula tiempo real si hay salida)
DELIMITER $$
CREATE PROCEDURE sp_marcar_entregado(IN p_id INT)
BEGIN
  UPDATE Entrega
  SET estatus = 'entregada',
      fecha_entrega = IFNULL(fecha_entrega, NOW()),
      tiempo_real_min = CASE WHEN fecha_salida IS NOT NULL
                             THEN TIMESTAMPDIFF(MINUTE, fecha_salida, IFNULL(fecha_entrega, NOW()))
                             ELSE tiempo_real_min END
  WHERE id_pedido = p_id;

  UPDATE Pedido SET estado = 'entregado' WHERE id_pedido = p_id;
END$$
DELIMITER ;

-- SP: ventas diarias (por fecha exacta) con desglose y suma total
DELIMITER $$
CREATE PROCEDURE sp_ventas_diarias(IN p_fecha DATE)
BEGIN
  -- Desglose de ventas del día
  SELECT p.id_pedido, c.nombre AS cliente, p.canal, p.estado, p.total, p.fecha_pedido
  FROM Pedido p
  JOIN Cliente c ON c.id_cliente = p.id_cliente
  WHERE DATE(p.fecha_pedido) = p_fecha
  ORDER BY p.fecha_pedido ASC;

  -- Resumen (suma de montos del mismo día)
  SELECT DATE(p.fecha_pedido) AS fecha, SUM(p.total) AS ventas_totales
  FROM Pedido p
  WHERE DATE(p.fecha_pedido) = p_fecha
  GROUP BY DATE(p.fecha_pedido);
END$$
DELIMITER ;

-- SP: clientes vigentes en Q1 (1 Ene – 31 Mar) para un año dado
DELIMITER $$
CREATE PROCEDURE sp_clientes_vigentes_Q1(IN p_anio INT)
BEGIN
  -- Lista de clientes con ≥1 pedido en Q1 del año indicado
  SELECT DISTINCT c.id_cliente, c.nombre, c.ap_paterno, c.email
  FROM Cliente c
  JOIN Pedido p ON p.id_cliente = c.id_cliente
  WHERE p.fecha_pedido >= CONCAT(p_anio, '-01-01')
    AND p.fecha_pedido <  CONCAT(p_anio, '-04-01')
  ORDER BY c.ap_paterno, c.nombre;
END$$
DELIMITER ;

-- SP: agregar cliente con manejo de “excepción de restricción única” (email único)
-- Nota: MySQL NO tiene TRY/CATCH como T-SQL; se maneja con HANDLER.
DELIMITER $$
CREATE PROCEDURE sp_agregar_cliente(
  IN p_nombre VARCHAR(50),
  IN p_ap_paterno VARCHAR(50),
  IN p_ap_materno VARCHAR(50),
  IN p_telefono VARCHAR(15),
  IN p_email VARCHAR(80)
)
BEGIN
  DECLARE CONTINUE HANDLER FOR 1062                   -- 1062 = Duplicate entry (violación UNIQUE)
  BEGIN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Email duplicado: ya existe un cliente con ese correo';
  END;

  INSERT INTO Cliente (nombre, ap_paterno, ap_materno, telefono, email)
  VALUES (p_nombre, p_ap_paterno, p_ap_materno, p_telefono, p_email);
END$$
DELIMITER ;

-- 4) DATOS DE EJEMPLO (postres)

-- Roles
INSERT INTO Rol (nombre_rol) VALUES
('Cajero'),('Repostero'),('Empaquetador'),('Repartidor'),('Supervisor');

-- Empleados
INSERT INTO Empleado (nombre, ap_paterno, ap_materno, telefono, id_rol) VALUES
('Ana','López','García','8111111111', 1),
('Luis','Pérez','Hernández','8222222222', 2),
('Mara','Ruiz','Torres','8333333333', 3),
('José','Martínez','Soto','8444444444', 4),
('Sofía','Gómez','Núñez','8555555555', 5);

-- Clientes
CALL sp_agregar_cliente('Juan','Pérez','López','8123456789','juan.postres@example.com');
CALL sp_agregar_cliente('Carla','García','Ruiz','8187654321','carla.postres@example.com');
CALL sp_agregar_cliente('Diego','Hernández','Mora','8112233445','diego.postres@example.com');
CALL sp_agregar_cliente('Sara','González','Vega','8119988776','sara.postres@example.com');
CALL sp_agregar_cliente('Pablo','Santos','Ibarra','8188001122','pablo.postres@example.com');

-- Proveedores
INSERT INTO Proveedor (nombre, telefono, email, direccion) VALUES
('Harinas del Norte','8110000001','ventas@harinasnorte.com','Monterrey, NL'),
('Dulces Selectos','8110000002','contacto@dulcesselectos.com','Guadalupe, NL'),
('La Canela Fina','8110000003','ventas@lacanelafina.com','San Nicolás, NL'),
('Cacao & Más','8110000004','info@cacaoymas.com','Apodaca, NL'),
('Lácteos Premium','8110000005','hola@lacteospremium.com','Monterrey, NL');

-- Ingredientes
INSERT INTO Ingrediente (nombre, unidad_medida, stock_actual, stock_minimo, precio_unitario, id_proveedor) VALUES
('Harina','g', 100000, 20000, 0.02, 1),
('Azúcar','g', 80000, 15000, 0.015, 2),
('Canela molida','g', 10000, 2000, 0.05, 3),
('Cacao en polvo','g', 15000, 3000, 0.04, 4),
('Chocolate amargo','g', 20000, 4000, 0.06, 4),
('Mantequilla','g', 25000, 5000, 0.08, 5),
('Huevo','pza', 2000, 400, 1.50, 5),
('Vainilla','ml', 5000, 1000, 0.03, 2);

-- Productos (postres)
INSERT INTO Producto (nombre, descripcion, precio_venta) VALUES
('Rollo de Canela','Rollo glaseado con canela', 45.00),
('Brownie','Brownie de chocolate amargo', 35.00),
('Galletas de Vainilla','Galletas crujientes de vainilla', 25.00),
('Galleta Chispas Choc','Galleta con chispas de chocolate', 28.00),
('Cuernito Dulce','Pan dulce glaseado', 22.00);

-- Recetas por porción
INSERT INTO Receta (id_producto, id_ingrediente, cantidad) VALUES
(1, 1, 120.00),(1, 2, 30.00),(1, 3, 5.00),(1, 6, 20.00),(1, 7, 1.00),
(2, 1, 80.00),(2, 2, 20.00),(2, 4, 30.00),(2, 5, 40.00),(2, 6, 25.00),(2, 7, 1.00),
(3, 1, 60.00),(3, 2, 15.00),(3, 6, 15.00),(3, 8, 5.00),(3, 7, 1.00),
(4, 1, 65.00),(4, 2, 15.00),(4, 6, 15.00),(4, 5, 25.00),(4, 7, 1.00),
(5, 1, 70.00),(5, 2, 15.00),(5, 6, 15.00),(5, 8, 4.00),(5, 7, 1.00);

-- Métodos de pago
INSERT INTO MetodoPago (nombre_metodo) VALUES
('Efectivo'),('Tarjeta'),('Transferencia'),('App de Delivery'),('Wallet');

-- Pedidos (5) con distintos canales
INSERT INTO Pedido (id_cliente, id_empleado, fecha_pedido, canal, estado, total) VALUES
(1, 1, NOW(), 'local', 'pendiente', 0.00),
(2, 1, NOW(), 'web',   'pendiente', 0.00),
(3, 1, NOW(), 'app',   'pendiente', 0.00),
(4, 1, NOW(), 'local', 'pendiente', 0.00),
(5, 1, NOW(), 'web',   'pendiente', 0.00);

-- Detalles (trigger calcula subtotal)
INSERT INTO DetallePedido (id_pedido, id_producto, cantidad, precio_unitario, subtotal) VALUES
(1, 1, 2, 45.00, 0.00),
(1, 2, 1, 35.00, 0.00),
(2, 3, 3, 25.00, 0.00),
(3, 4, 2, 28.00, 0.00),
(4, 2, 4, 35.00, 0.00),
(5, 1, 1, 45.00, 0.00),
(5, 5, 2, 22.00, 0.00);

-- Confirmo todos para descontar inventario y actualizar total
CALL sp_confirmar_pedido(1);
CALL sp_confirmar_pedido(2);
CALL sp_confirmar_pedido(3);
CALL sp_confirmar_pedido(4);
CALL sp_confirmar_pedido(5);

-- Pagos (monto = suma de subtotales por pedido)
INSERT INTO Pago (id_pedido, id_metodo, monto, fecha_pago)
SELECT p.id_pedido,
       CASE p.id_pedido WHEN 1 THEN 2 WHEN 2 THEN 1 WHEN 3 THEN 4 WHEN 4 THEN 5 ELSE 3 END AS id_metodo,
       t.total AS monto,
       NOW()
FROM Pedido p
JOIN (SELECT id_pedido, SUM(subtotal) AS total FROM DetallePedido GROUP BY id_pedido) t
  ON t.id_pedido = p.id_pedido;

-- Entregas (todas al repartidor id=4)
INSERT INTO Entrega (id_pedido, id_empleado_repartidor, fecha_salida, estatus, tiempo_estimado_min)
VALUES
(1, 4, NOW(), 'en_ruta', 30),
(2, 4, NOW(), 'en_ruta', 25),
(3, 4, NOW(), 'en_ruta', 35),
(4, 4, NOW(), 'en_ruta', 20),
(5, 4, NOW(), 'en_ruta', 30);

-- Marco 2 pedidos como entregados
CALL sp_marcar_entregado(1);
CALL sp_marcar_entregado(2);

-- 5) MOSTRAR TABLAS Y DATOS
SHOW TABLES;

SELECT 'Rol' AS tabla, COUNT(*) AS filas FROM Rol
UNION ALL SELECT 'Empleado', COUNT(*) FROM Empleado
UNION ALL SELECT 'Cliente', COUNT(*) FROM Cliente
UNION ALL SELECT 'Proveedor', COUNT(*) FROM Proveedor
UNION ALL SELECT 'Ingrediente', COUNT(*) FROM Ingrediente
UNION ALL SELECT 'Producto', COUNT(*) FROM Producto
UNION ALL SELECT 'Receta', COUNT(*) FROM Receta
UNION ALL SELECT 'Pedido', COUNT(*) FROM Pedido
UNION ALL SELECT 'DetallePedido', COUNT(*) FROM DetallePedido
UNION ALL SELECT 'MetodoPago', COUNT(*) FROM MetodoPago
UNION ALL SELECT 'Pago', COUNT(*) FROM Pago
UNION ALL SELECT 'Entrega', COUNT(*) FROM Entrega
UNION ALL SELECT 'SeguimientoCliente', COUNT(*) FROM SeguimientoCliente;

SELECT * FROM Producto LIMIT 10;
SELECT * FROM Ingrediente LIMIT 10;
SELECT * FROM Pedido ORDER BY fecha_pedido DESC;
SELECT * FROM SeguimientoCliente ORDER BY fecha_hora DESC;

-- 6) CONSULTAS “AVANZADAS” (JOIN, UNION, ORDER BY, GROUP BY, FECHAS)

-- JOIN + GROUP BY: ingresos por producto
SELECT pr.nombre AS producto, SUM(d.cantidad) AS unidades, SUM(d.subtotal) AS ingresos
FROM DetallePedido d
JOIN Producto pr ON pr.id_producto = d.id_producto
GROUP BY pr.nombre
ORDER BY ingresos DESC;

-- UNION: ejemplo simple sobre emails (ajústalo a tu dominio si deseas)
SELECT id_cliente, nombre, ap_paterno, email, 'institucional' AS tipo
FROM Cliente WHERE email LIKE '%.com%'
UNION
SELECT id_cliente, nombre, ap_paterno, email, 'gmail' AS tipo
FROM Cliente WHERE email LIKE '%@gmail.%'
ORDER BY ap_paterno, nombre;

-- Fechas + ORDER BY: pedidos de últimos 7 días, más reciente primero
SELECT id_pedido, id_cliente, canal, estado, total, fecha_pedido
FROM Pedido
WHERE fecha_pedido BETWEEN DATE_SUB(CURDATE(), INTERVAL 7 DAY) AND NOW()
ORDER BY fecha_pedido DESC;

-- GROUP BY por canal (ventas por canal)
SELECT canal, COUNT(*) AS pedidos, SUM(total) AS ventas
FROM Pedido
GROUP BY canal
ORDER BY ventas DESC;

-- SP de ejemplo: ventas de HOY
-- CALL sp_ventas_diarias(CURDATE());

-- SP de ejemplo: clientes vigentes Q1 del año actual
-- CALL sp_clientes_vigentes_Q1(YEAR(CURDATE()));
