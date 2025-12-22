//
//  FirebaseDataManager.swift
//  HKBusApp
//
//  Created by Claude Code on 2025-12-13.
//  Manages Firebase Storage downloads for bus data updates
//

import Foundation
import FirebaseStorage
import FirebaseAuth
import CryptoKit

class FirebaseDataManager {
    static let shared = FirebaseDataManager()

    private let storage = Storage.storage()
    private let userDefaults = UserDefaults.standard

    // UserDefaults keys
    private let LOCAL_VERSION_KEY = "com.hkbusapp.localBusDataVersion"
    private let LAST_CHECK_TIME_KEY = "com.hkbusapp.lastVersionCheckTime"
    private let CHECK_INTERVAL: TimeInterval = 86400  // 24小時

    private init() {}

    // MARK: - Version Check

    /// 檢查是否有新版本（24小時節流）
    func checkForUpdates(forceCheck: Bool = false, completion: @escaping (Result<Bool, Error>) -> Void) {
        // 節流檢查（除非強制檢查）
        if !forceCheck {
            let lastCheck = userDefaults.double(forKey: LAST_CHECK_TIME_KEY)
            let now = Date().timeIntervalSince1970

            if now - lastCheck < CHECK_INTERVAL {
                print("⏰ 距離上次檢查不足24小時，跳過檢查")
                completion(.success(false))
                return
            }
        }

        // 匿名登錄 Firebase（通過 Security Rules 驗證）
        Auth.auth().signInAnonymously { authResult, error in
            if let error = error {
                print("❌ Firebase 匿名登錄失敗")
                print("   錯誤域: \((error as NSError).domain)")
                print("   錯誤代碼: \((error as NSError).code)")
                completion(.failure(error))
                return
            }

            print("✅ Firebase 匿名登錄成功")

            // 下載 metadata.json
            self.downloadMetadata { result in
                switch result {
                case .success(let metadata):
                    let remoteVersion = metadata.version
                    let localVersion = self.getLocalVersion()

                    print("📡 遠程版本: \(remoteVersion)")
                    print("📱 本地版本: \(localVersion)")

                    // 更新檢查時間
                    let now = Date().timeIntervalSince1970
                    self.userDefaults.set(now, forKey: self.LAST_CHECK_TIME_KEY)

                    if remoteVersion > localVersion {
                        print("🆕 發現新版本！")
                        completion(.success(true))
                    } else {
                        print("✅ 已是最新版本")
                        completion(.success(false))
                    }

                case .failure(let error):
                    print("❌ Metadata 下載失敗")
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - Download Data

    /// 下載最新的 bus_data.json
    func downloadBusData(progressHandler: @escaping (Double) -> Void,
                         completion: @escaping (Result<URL, Error>) -> Void) {

        let storageRef = storage.reference(withPath: "bus_data.json")

        // 臨時文件路徑
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("bus_data_download.json")

        // 刪除舊的臨時文件
        try? FileManager.default.removeItem(at: tempURL)

        print("📥 開始下載 bus_data.json...")

        var hasCompleted = false

        // 30 秒 timeout
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
            if !hasCompleted {
                hasCompleted = true
                print("⏱️ 下載超時（30秒）")
                let timeoutError = NSError(domain: "FirebaseDataManager",
                                          code: -100,
                                          userInfo: [NSLocalizedDescriptionKey: "連線逾時，請檢查網路連線並稍後再試"])
                completion(.failure(timeoutError))
            }
        }

        // 開始下載
        let downloadTask = storageRef.write(toFile: tempURL) { url, error in
            timeoutTimer.invalidate()

            guard !hasCompleted else { return }
            hasCompleted = true
            if let error = error {
                print("❌ 下載失敗")
                completion(.failure(error))
                return
            }

            guard let url = url else {
                let error = NSError(domain: "FirebaseDataManager",
                                   code: -1,
                                   userInfo: [NSLocalizedDescriptionKey: "下載失敗：URL 為空"])
                completion(.failure(error))
                return
            }

            print("✅ 下載完成: \(url.path)")

            // 驗證文件完整性
            self.verifyDownloadedFile(at: url) { isValid in
                if isValid {
                    print("✅ 文件校驗通過")
                    completion(.success(url))
                } else {
                    let error = NSError(domain: "FirebaseDataManager",
                                       code: -2,
                                       userInfo: [NSLocalizedDescriptionKey: "文件校驗失敗"])
                    print("❌ 文件校驗失敗")
                    completion(.failure(error))
                }
            }
        }

        // 監聽下載進度
        downloadTask.observe(.progress) { snapshot in
            guard let progress = snapshot.progress else { return }
            let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)

            DispatchQueue.main.async {
                progressHandler(percentComplete)
            }

            // 每 10% 打印一次進度
            let percent = Int(percentComplete * 100)
            if percent % 10 == 0 {
                print("📊 下載進度: \(percent)%")
            }
        }
    }

    // MARK: - Install Data

    /// 安裝下載的數據到 Documents 目錄
    func installDownloadedData(from tempURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let targetURL = documentsURL.appendingPathComponent("bus_data.json")

        do {
            // 刪除舊文件
            if FileManager.default.fileExists(atPath: targetURL.path) {
                try FileManager.default.removeItem(at: targetURL)
                print("🗑️ 已刪除舊數據文件")
            }

            // 移動新文件
            try FileManager.default.moveItem(at: tempURL, to: targetURL)
            print("📦 新數據已安裝: \(targetURL.path)")

            // 讀取版本並保存
            if let data = try? Data(contentsOf: targetURL),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let version = json["version"] as? Int {
                userDefaults.set(version, forKey: LOCAL_VERSION_KEY)
                print("✅ 版本已更新: \(version)")
            }

            // 重新載入 LocalBusDataManager
            _ = LocalBusDataManager.shared.reloadData()
            print("🔄 數據已重新載入")

            completion(.success(()))

        } catch {
            print("❌ 安裝失敗")
            completion(.failure(error))
        }
    }

    // MARK: - Private Methods

    private func downloadMetadata(completion: @escaping (Result<BusDataMetadata, Error>) -> Void) {
        let metadataRef = storage.reference(withPath: "bus_data_metadata.json")

        print("📋 正在下載 metadata...")

        var hasCompleted = false

        // 30 秒 timeout
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
            if !hasCompleted {
                hasCompleted = true
                print("⏱️ Metadata 下載超時（30秒）")
                let timeoutError = NSError(domain: "FirebaseDataManager",
                                          code: -101,
                                          userInfo: [NSLocalizedDescriptionKey: "連線逾時，請檢查網路連線並稍後再試"])
                completion(.failure(timeoutError))
            }
        }

        metadataRef.getData(maxSize: 10 * 1024) { data, error in  // 最大 10KB
            timeoutTimer.invalidate()

            guard !hasCompleted else { return }
            hasCompleted = true
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                let error = NSError(domain: "FirebaseDataManager",
                                   code: -3,
                                   userInfo: [NSLocalizedDescriptionKey: "Metadata 為空"])
                completion(.failure(error))
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let metadata = try decoder.decode(BusDataMetadata.self, from: data)
                print("✅ Metadata 下載成功")
                completion(.success(metadata))
            } catch {
                print("❌ Metadata 解析失敗: \(error)")
                completion(.failure(error))
            }
        }
    }

    private func verifyDownloadedFile(at url: URL, completion: @escaping (Bool) -> Void) {
        // 下載 metadata 獲取預期的 MD5
        downloadMetadata { result in
            switch result {
            case .success(let metadata):
                // 計算實際文件的 MD5
                guard let fileData = try? Data(contentsOf: url) else {
                    print("❌ 無法讀取文件進行校驗")
                    completion(false)
                    return
                }

                let digest = Insecure.MD5.hash(data: fileData)
                let actualMD5 = digest.map { String(format: "%02hhx", $0) }.joined()

                // 比對
                if actualMD5 == metadata.md5Checksum {
                    print("✅ MD5 校驗通過")
                    print("   預期: \(metadata.md5Checksum)")
                    print("   實際: \(actualMD5)")
                    completion(true)
                } else {
                    print("❌ MD5 校驗失敗")
                    print("   預期: \(metadata.md5Checksum)")
                    print("   實際: \(actualMD5)")
                    completion(false)
                }

            case .failure:
                // 如果無法下載 metadata，跳過驗證（降級策略）
                print("⚠️ 無法驗證文件（metadata 下載失敗），跳過校驗")
                completion(true)
            }
        }
    }

    private func getLocalVersion() -> Int {
        // 優先從 UserDefaults 讀取已安裝版本
        let savedVersion = userDefaults.integer(forKey: LOCAL_VERSION_KEY)
        if savedVersion > 0 {
            return savedVersion
        }

        // 否則從 LocalBusDataManager 讀取
        return LocalBusDataManager.shared.getCurrentVersion() ?? 0
    }
}

// MARK: - Data Models

struct BusDataMetadata: Codable {
    let version: Int
    let generatedAt: String
    let fileSizeBytes: Int
    let md5Checksum: String
    let sha256Checksum: String?
    let summary: BusDataSummary
    let downloadUrl: String
}

struct BusDataSummary: Codable {
    let totalRoutes: Int
    let totalStops: Int
    let totalMappings: Int
    let companies: [String]
}
