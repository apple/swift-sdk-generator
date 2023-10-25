//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import AsyncHTTPClient
import Foundation
import SystemPackage

extension FileDownloadDelegate.Progress: @unchecked Sendable {}

extension FilePath: @unchecked Sendable {}

extension HTTPClient {
  func downloadFile(
    from url: URL,
    to path: FilePath
  ) async throws -> FileDownloadDelegate.Progress {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<
      FileDownloadDelegate.Progress,
      Error
    >) in
      do {
        let delegate = try FileDownloadDelegate(
          path: path.string,
          reportHead: { task, responseHead in
            if responseHead.status != .ok {
              task.fail(reason: GeneratorError.fileDownloadFailed(url, responseHead.status))
            }
          }
        )
        let request = try HTTPClient.Request(url: url)

        execute(request: request, delegate: delegate).futureResult.whenComplete {
          switch $0 {
          case let .failure(error):
            continuation.resume(throwing: error)
          case let .success(finalProgress):
            continuation.resume(returning: finalProgress)
          }
        }
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }

  func streamDownloadProgress(
    for artifact: DownloadableArtifacts.Item
  ) -> AsyncThrowingStream<FileDownloadDelegate.Progress, any Error> {
    .init { continuation in
      do {
        let delegate = try FileDownloadDelegate(
          path: artifact.localPath.string,
          reportHead: {
            if $0.status != .ok {
              continuation
                .finish(throwing: FileOperationError.downloadFailed(artifact.remoteURL, $0.status))
            }
          },
          reportProgress: {
            continuation.yield($0)
          }
        )
        let request = try HTTPClient.Request(url: artifact.remoteURL)

        execute(request: request, delegate: delegate).futureResult.whenComplete {
          switch $0 {
          case let .failure(error):
            continuation.finish(throwing: error)
          case let .success(finalProgress):
            continuation.yield(finalProgress)
            continuation.finish()
          }
        }
      } catch {
        continuation.finish(throwing: error)
      }
    }
  }

  func downloadFiles(
    from urls: [URL],
    to directory: FilePath
  ) async throws -> [FileDownloadDelegate.Progress] {
    try await withThrowingTaskGroup(of: FileDownloadDelegate.Progress.self) {
      for url in urls {
        $0.addTask {
          try await self.downloadFile(from: url, to: directory.appending(url.lastPathComponent))
        }
      }

      var result = [FileDownloadDelegate.Progress]()
      for try await progress in $0 {
        result.append(progress)
      }
      return result
    }
  }
}
