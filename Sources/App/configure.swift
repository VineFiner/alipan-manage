import Fluent
import FluentSQLiteDriver
import AliPdsCredentialsFluent
import Vapor

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // 配置数据库
    app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)

    app.migrations.add(CreateTodo())

    // MARK: App Config
    app.config = .environment
    
    // http://127.0.0.1:8080/pdsfolder/example.txt
    if app.config.pdsAbsoluteFolderPath.isEmpty {
        app.config.pdsAbsoluteFolderPath = app.directory.publicDirectory + "pdsfolder"
    }
    // MARK: Config AliPDS
    app.aliPds.storage = .init(credentials: .init(secret: app.config.aliPdsSecret))
    app.aliPds.use { app in
        return DatabasePDSAccountCredential.init(db: app.db)
    }
    app.migrations.add(PDSAccountCredentialsRecord.migration)
    
    if app.environment == .development {
        // 自动 migrate 数据库
        try app.autoMigrate().wait()
    }

    // register routes
    try routes(app)
}
