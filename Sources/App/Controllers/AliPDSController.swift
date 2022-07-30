//
//  File.swift
//  
//
//  Created by Finer  Vine on 2021/7/11.
//

import Foundation
import AliPdsVapor
import Vapor

struct AliPDSController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let ali = routes.grouped("api", "ali")
        
        ali.get("list", use: list)
        ali.get("query", use: queryInfo(req:))
        ali.get("path", use: searchPathInfo)
        ali.get("detail", use: detail(req:))
        ali.get("download", use: downloadInfo(req:))
        
        // 受保护，或者只允许登录用户运行
//        let protectedRoutes = ali.grouped([
//                User.sessionAuthenticator(),
//                User.guardMiddleware(),
//                User.redirectMiddleware(path: "/login")
//            ])
        let protectedRoutes = ali
        protectedRoutes.group("auth") { protected in
            protected.get("local", use: localFile)
            protected.get("create", use: createFolder(req:))
            protected.post("upload", use: uploadFile(req:))
        }
    }
    
    /// 文件列表  http://127.0.0.1:8080/api/ali/list?parentId=root
    func list(req: Request) async throws -> FileDriveModel {
        guard let parentfileId = req.query[String.self, at: "parentId"] else {
            throw Abort(.notFound, reason: "Please input parentId")
        }
        return try await req.driveClient.drive.getFileList(driveId: AppConfig.environment.driveId, parentFileId: parentfileId, queryParameters: nil)
    }
    
    /// 查询 http://127.0.0.1:8080/api/ali/query?name=name match "CQfa2wCjugf"
    func queryInfo(req: Request) async throws -> PDSSearchFileResponse {
        guard let name = req.query[String.self, at: "name"] else {
            throw Abort(.notFound, reason: "Please input user name")
        }
        let query = PDSSearchFileRequest.init(driveId: AppConfig.environment.driveId, query: name)
        return try await req.driveClient.drive.searchDriveFileOrFolder(body: query)
    }

    // 路径搜索 http://127.0.0.1:8080/api/ali/path?name=/ins
    func searchPathInfo(req: Request) async throws -> PDSGetFileByPathResponse {
        guard let name = req.query[String.self, at: "name"] else {
            throw Abort(.notFound, reason: "Please input user name")
        }
        let query = PDSGetFileByPathRequest.init(driveId: AppConfig.environment.driveId, fileID: "root",filePath: name)
        return try await req.driveClient.drive.getByPathFileOrFolderInfo(body: query)
    }
    
    // 文件详情 http://127.0.0.1:8080/api/ali/detail?fileId=60cf0bc1f0111c343bf84db7aa0ce2a9aaf654fb
    func detail(req: Request) async throws -> PDSGetFileResponse {
        guard let fileId = req.query[String.self, at: "fileId"] else {
            throw Abort(.notFound, reason: "Please input fileId")
        }
        let query = PDSGetFileRequest.init(driveId: AppConfig.environment.driveId, fileId: fileId)
        return try await req.driveClient.drive.getFileOrFolderInfo(body: query)
    }
    
    // 获取下载链接 http://127.0.0.1:8080/api/ali/download?fileId=60cf0bc1f0111c343bf84db7aa0ce2a9aaf654fb
    func downloadInfo(req: Request) async throws -> PDSGetDownloadUrlResponse {
        guard let fileId = req.query[String.self, at: "fileId"] else {
            throw Abort(.notFound, reason: "Please input fileId")
        }
        let query = PDSGetDownloadUrlRequest(driveId: AppConfig.environment.driveId, fileId: fileId)
        return try await req.driveClient.drive.getFileDownloadUrl(body: query)
    }
    
    // 创建文件夹 http://127.0.0.1:8080/api/ali/auth/create?name=/me
    func createFolder(req: Request) async throws -> PDSCreateFileResponse {
        
        guard let name = req.query[String.self, at: "name"],
              let url = URL(string: "\(name)") else {
            throw Abort(.notFound, reason: "Please input user name")
        }
        return try await req.driveClient.drive.createDepthFolder(driveId: AppConfig.environment.driveId, path: url)
    }
    
    struct UploadFile: Decodable {
        let pdsParentFileId: String
        let localPath: String
        let localFileName: String
    }
    /* 从服务器上传文件到PDS
     curl -i -X POST "http://127.0.0.1:8080/api/ali/auth/upload" \
     -H "Content-Type: application/json" \
     -d '{"pdsParentFileId": "root", "localPath": "", "localFileName": "example.txt"}'
     */
    func uploadFile(req: Request) async throws -> PDSCompleteFileResponse {
        let driveId: String = AppConfig.environment.driveId

        let patchInfo = try req.content.decode(UploadFile.self)
        
        let parentId = patchInfo.pdsParentFileId
        let path = patchInfo.localPath.isEmpty ? "/" : "/\(patchInfo.localPath)/"
        let name = patchInfo.localFileName
        let absolutePath = req.application.config.pdsAbsoluteFolderPath + "\(path)" + name
        
        req.logger.info("upload path:\(absolutePath)")
        return try await req.driveClient.drive.createAndUploadFile(driveId: driveId, parentFileId: parentId, name: name, localPath: absolutePath)
    }
    
    /// 本地文件 不带前导斜杠
    /// - Parameter req: 请求 http://127.0.0.1:8080/api/ali/auth/local?path=example.txt
    /// - Returns: 响应
    func localFile(req: Request) async throws -> Response {
        
        // make a copy of the percent-decoded path
        // 制作百分比解码路径的副本
        guard var path = req.query[String.self, at: "path"]?.removingPercentEncoding else {
            throw Abort(.badRequest, reason: "Please input path")
        }
        
        // 移除前导斜杠
        if path.hasPrefix("/") {
            path.removeFirst()
        }

        // create absolute path
        // 创建绝对路径
        let absPath = req.application.config.pdsAbsoluteFolderPath + "/\(path)"

        // check if path exists and whether it is a directory
        // 检查路径是否存在以及是否为目录
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: absPath, isDirectory: &isDir) else {
            throw Abort(.forbidden)
        }
        
        if isDir.boolValue {
            throw Abort(.forbidden, reason: "This is Dir")
        }
        
        // stream the file
        let res = req.fileio.streamFile(at: absPath)
        return res
    }
}

extension PDSGetDownloadUrlResponse: Content { }
extension PDSGetFileResponse: Content { }
extension PDSCreateFileResponse: Content { }
extension PDSGetFileByPathResponse: Content { }
extension PDSSearchFileResponse: Content { }
extension PDSCompleteFileResponse: Content { }
extension FileDriveModel: Content { }
