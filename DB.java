// JDBC connection class

// DB.java
// Clase de conexión JDBC a MySQL con comentarios línea por línea

import java.sql.Connection;         // Importo la clase Connection para manejar la conexión a la BD
import java.sql.DriverManager;      // Importo DriverManager para obtener la conexión con URL/usuario/pass
import java.sql.SQLException;       // Importo SQLException para capturar errores de BD

public class DB {
    // URL de conexión a MySQL (ajusta el puerto, host y schema si es necesario)
    // "useSSL=false" y "serverTimezone=UTC" ayudan a evitar advertencias de zona horaria/SSL
    private static final String URL = "jdbc:mysql://localhost:3306/proyectofinal?useSSL=false&serverTimezone=UTC";
    // Usuario de MySQL (ajústalo a tu usuario real)
    private static final String USER = "root";
    // Contraseña de MySQL (ajústala a tu contraseña real)
    private static final String PASS = "Korova312";

    // Método estático para obtener una conexión abierta
    public static Connection getConnection() throws SQLException {
        // Llamo a DriverManager.getConnection con URL/USER/PASS y regreso la conexión abierta
        return DriverManager.getConnection(URL, USER, PASS);
    }
}
