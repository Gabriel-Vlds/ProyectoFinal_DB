
// MainApp.java
// App Swing con dos interfaces: "Hacer Pedido" y "Panel Admin (login + gestión)"
// Comentarios línea por línea y SQL con PreparedStatement para seguridad.

import javax.swing.*;                            // Importo Swing para la interfaz gráfica
import javax.swing.table.DefaultTableModel;      // Para mostrar datos en tablas (JTable)
import java.awt.*;                               // Para layouts y componentes
import java.awt.event.*;                         // Para eventos de botones
import java.sql.*;                               // Para JDBC (Connection, PreparedStatement, ResultSet)
import java.math.BigDecimal;                     // Para manejar precios de forma segura

public class MainApp extends JFrame {
    private JTabbedPane tabs;                    // Contenedor de pestañas

    // --- Pestaña "Hacer Pedido" ---
    private JTextField txtIdCliente;
    private JComboBox<String> cboCanal;
    private JTextField txtIdProducto;
    private JTextField txtCantidad;
    private JButton btnCrearPedido;

    // --- Pestaña "Panel Admin" ---
    private JPanel panelLogin;
    private JPanel panelAdmin;
    private JTextField txtUsuario;
    private JPasswordField txtPassword;
    private JButton btnLogin;

    private JTable tblPedidos;
    private DefaultTableModel modelPedidos;

    private JTable tblIngredientes;
    private DefaultTableModel modelIngredientes;
    private JTextField txtIngNombre;
    private JTextField txtIngUnidad;
    private JTextField txtIngStock;
    private JTextField txtIngMin;
    private JTextField txtIngPrecio;
    private JTextField txtIngProveedor;
    private JButton btnAgregarIngrediente;

    public MainApp() {
        setTitle("Dark Kitchen de Postres - Demo");
        setSize(900, 600);
        setLocationRelativeTo(null);
        setDefaultCloseOperation(EXIT_ON_CLOSE);

        tabs = new JTabbedPane();
        tabs.addTab("Hacer Pedido", buildPedidoPanel());
        tabs.addTab("Panel Admin", buildAdminPanel());
        add(tabs);
    }

    private JPanel buildPedidoPanel() {
        JPanel panel = new JPanel(new BorderLayout(10,10));
        JPanel form = new JPanel(new GridLayout(0,2,8,8));

        form.add(new JLabel("ID Cliente:"));
        txtIdCliente = new JTextField("1");
        form.add(txtIdCliente);

        form.add(new JLabel("Canal:"));
        cboCanal = new JComboBox<>(new String[]{"local","web","app"});
        form.add(cboCanal);

        form.add(new JLabel("ID Producto:"));
        txtIdProducto = new JTextField("1");
        form.add(txtIdProducto);

        form.add(new JLabel("Cantidad:"));
        txtCantidad = new JTextField("2");
        form.add(txtCantidad);

        btnCrearPedido = new JButton("Crear Pedido");
        btnCrearPedido.addActionListener(e -> crearPedido());

        panel.add(form, BorderLayout.NORTH);
        panel.add(btnCrearPedido, BorderLayout.SOUTH);
        return panel;
    }

    private JPanel buildAdminPanel() {
        JPanel container = new JPanel(new CardLayout());

        panelLogin = new JPanel(new GridLayout(0,2,8,8));
        panelLogin.setBorder(BorderFactory.createEmptyBorder(20, 20, 20, 20));
        panelLogin.add(new JLabel("Usuario:"));
        txtUsuario = new JTextField();
        panelLogin.add(txtUsuario);

        panelLogin.add(new JLabel("Contraseña:"));
        txtPassword = new JPasswordField();      // Contraseña oculta
        panelLogin.add(txtPassword);

        btnLogin = new JButton("Entrar");
        btnLogin.addActionListener(e -> validarLogin(container));
        panelLogin.add(new JLabel());
        panelLogin.add(btnLogin);

        panelAdmin = new JPanel(new BorderLayout(10,10));
        JPanel top = new JPanel(new FlowLayout(FlowLayout.LEFT));
        JButton btnCargarPedidos = new JButton("Ver Pedidos");
        btnCargarPedidos.addActionListener(e -> cargarPedidos());
        JButton btnCargarIngredientes = new JButton("Ver Ingredientes");
        btnCargarIngredientes.addActionListener(e -> cargarIngredientes());
        top.add(btnCargarPedidos);
        top.add(btnCargarIngredientes);

        modelPedidos = new DefaultTableModel(new String[]{"id_pedido","cliente","canal","estado","total","fecha"}, 0);
        tblPedidos = new JTable(modelPedidos);

        modelIngredientes = new DefaultTableModel(new String[]{"id","nombre","unidad","stock","mínimo","precio","proveedor"}, 0);
        tblIngredientes = new JTable(modelIngredientes);

        JSplitPane split = new JSplitPane(JSplitPane.VERTICAL_SPLIT,
                new JScrollPane(tblPedidos), new JScrollPane(tblIngredientes));
        split.setResizeWeight(0.5);

        JPanel bottom = new JPanel(new GridLayout(0,7,6,6));
        txtIngNombre = new JTextField();
        txtIngUnidad = new JTextField();
        txtIngStock  = new JTextField("1000");
        txtIngMin    = new JTextField("200");
        txtIngPrecio = new JTextField("0.02");
        txtIngProveedor = new JTextField("1");
        btnAgregarIngrediente = new JButton("Agregar Ingrediente");

        bottom.add(new JLabel("Nombre")); bottom.add(txtIngNombre);
        bottom.add(new JLabel("Unidad")); bottom.add(txtIngUnidad);
        bottom.add(new JLabel("Stock"));  bottom.add(txtIngStock);
        bottom.add(new JLabel("Mín"));    bottom.add(txtIngMin);
        bottom.add(new JLabel("Precio")); bottom.add(txtIngPrecio);
        bottom.add(new JLabel("ProvId")); bottom.add(txtIngProveedor);
        bottom.add(new JLabel());         bottom.add(btnAgregarIngrediente);

        btnAgregarIngrediente.addActionListener(e -> agregarIngrediente());

        panelAdmin.add(top, BorderLayout.NORTH);
        panelAdmin.add(split, BorderLayout.CENTER);
        panelAdmin.add(bottom, BorderLayout.SOUTH);

        container.add(panelLogin, "login");
        container.add(panelAdmin, "admin");

        return container;
    }

    private void validarLogin(JPanel container) {
        String user = txtUsuario.getText();
        String pass = new String(txtPassword.getPassword());
        if ("admin".equals(user) && "1234".equals(pass)) {
            CardLayout cl = (CardLayout) container.getLayout();
            cl.show(container, "admin");
            cargarPedidos();
            cargarIngredientes();
        } else {
            JOptionPane.showMessageDialog(this, "Usuario/contraseña incorrectos", "Error", JOptionPane.ERROR_MESSAGE);
        }
    }

    private void crearPedido() {
        int idCliente = Integer.parseInt(txtIdCliente.getText().trim());
        String canal = (String) cboCanal.getSelectedItem();
        int idProducto = Integer.parseInt(txtIdProducto.getText().trim());
        int cantidad = Integer.parseInt(txtCantidad.getText().trim());

        try (Connection cn = DB.getConnection()) {
            cn.setAutoCommit(false);

            String sqlPedido = "INSERT INTO Pedido (id_cliente, id_empleado, fecha_pedido, canal, estado, total) " +
                               "VALUES (?, 1, NOW(), ?, 'pendiente', 0.00)";
            int idPedido = 0;
            try (PreparedStatement ps = cn.prepareStatement(sqlPedido, Statement.RETURN_GENERATED_KEYS)) {
                ps.setInt(1, idCliente);
                ps.setString(2, canal);
                ps.executeUpdate();
                try (ResultSet rs = ps.getGeneratedKeys()) {
                    if (rs.next()) idPedido = rs.getInt(1);
                }
            }

            BigDecimal precioUnit = BigDecimal.ZERO;
            try (PreparedStatement ps = cn.prepareStatement("SELECT precio_venta FROM Producto WHERE id_producto=?")) {
                ps.setInt(1, idProducto);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) precioUnit = rs.getBigDecimal(1);
                    else throw new SQLException("Producto no encontrado");
                }
            }

            try (PreparedStatement ps = cn.prepareStatement(
                    "INSERT INTO DetallePedido (id_pedido, id_producto, cantidad, precio_unitario, subtotal) VALUES (?, ?, ?, ?, 0.00)")) {
                ps.setInt(1, idPedido);
                ps.setInt(2, idProducto);
                ps.setInt(3, cantidad);
                ps.setBigDecimal(4, precioUnit);
                ps.executeUpdate();
            }

            try (CallableStatement cs = cn.prepareCall("{CALL sp_confirmar_pedido(?)}")) {
                cs.setInt(1, idPedido);
                cs.execute();
            }

            cn.commit();
            JOptionPane.showMessageDialog(this, "Pedido creado con ID: " + idPedido);
        } catch (Exception ex) {
            JOptionPane.showMessageDialog(this, "Error al crear pedido: " + ex.getMessage(), "Error", JOptionPane.ERROR_MESSAGE);
        }
    }

    private void cargarPedidos() {
        modelPedidos.setRowCount(0);
        String sql = "SELECT p.id_pedido, c.nombre AS cliente, p.canal, p.estado, p.total, p.fecha_pedido " +
                     "FROM Pedido p JOIN Cliente c ON c.id_cliente = p.id_cliente " +
                     "ORDER BY p.fecha_pedido DESC";
        try (Connection cn = DB.getConnection();
             PreparedStatement ps = cn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                modelPedidos.addRow(new Object[]{
                        rs.getInt("id_pedido"),
                        rs.getString("cliente"),
                        rs.getString("canal"),
                        rs.getString("estado"),
                        rs.getBigDecimal("total"),
                        rs.getTimestamp("fecha_pedido")
                });
            }
        } catch (Exception e) {
            JOptionPane.showMessageDialog(this, "Error al cargar pedidos: " + e.getMessage());
        }
    }

    private void cargarIngredientes() {
        modelIngredientes.setRowCount(0);
        String sql = "SELECT i.id_ingrediente, i.nombre, i.unidad_medida, i.stock_actual, i.stock_minimo, " +
                     "i.precio_unitario, p.nombre AS proveedor " +
                     "FROM Ingrediente i JOIN Proveedor p ON p.id_proveedor = i.id_proveedor " +
                     "ORDER BY i.nombre ASC";
        try (Connection cn = DB.getConnection();
             PreparedStatement ps = cn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                modelIngredientes.addRow(new Object[]{
                        rs.getInt("id_ingrediente"),
                        rs.getString("nombre"),
                        rs.getString("unidad_medida"),
                        rs.getInt("stock_actual"),
                        rs.getInt("stock_minimo"),
                        rs.getBigDecimal("precio_unitario"),
                        rs.getString("proveedor")
                });
            }
        } catch (Exception e) {
            JOptionPane.showMessageDialog(this, "Error al cargar ingredientes: " + e.getMessage());
        }
    }

    private void agregarIngrediente() {
        String nombre = txtIngNombre.getText().trim();
        String unidad = txtIngUnidad.getText().trim();
        int stock = Integer.parseInt(txtIngStock.getText().trim());
        int minimo = Integer.parseInt(txtIngMin.getText().trim());
        double precio = Double.parseDouble(txtIngPrecio.getText().trim());
        int provId = Integer.parseInt(txtIngProveedor.getText().trim());

        String sql = "INSERT INTO Ingrediente (nombre, unidad_medida, stock_actual, stock_minimo, precio_unitario, id_proveedor) " +
                     "VALUES (?, ?, ?, ?, ?, ?)";
        try (Connection cn = DB.getConnection();
             PreparedStatement ps = cn.prepareStatement(sql)) {
            ps.setString(1, nombre);
            ps.setString(2, unidad);
            ps.setInt(3, stock);
            ps.setInt(4, minimo);
            ps.setDouble(5, precio);
            ps.setInt(6, provId);
            ps.executeUpdate();
            JOptionPane.showMessageDialog(this, "Ingrediente agregado");
            cargarIngredientes();
        } catch (Exception e) {
            JOptionPane.showMessageDialog(this, "Error al agregar ingrediente: " + e.getMessage(), "Error", JOptionPane.ERROR_MESSAGE);
        }
    }

    public static void main(String[] args) {
        SwingUtilities.invokeLater(() -> {
            new MainApp().setVisible(true);
        });
    }
}
