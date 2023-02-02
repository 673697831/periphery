import Foundation
import SystemPackage
import Shared
import PeripheryKit

final class ScanBehavior {
    private let configuration: Configuration
    private let logger: Logger

    required init(configuration: Configuration = .shared, logger: Logger = .init()) {
        self.configuration = configuration
        self.logger = logger
    }

    func setup(_ configPath: String?) -> Result<(), PeripheryError> {
        do {
            var path: FilePath?

            if let configPath = configPath {
                path = FilePath(configPath)
            }
            try configuration.load(from: path)
        } catch let error as PeripheryError {
            return .failure(error)
        } catch {
            return .failure(.underlyingError(error))
        }

        return .success(())
    }

    func main(_ block: (Project) throws -> [ScanResult]) -> Result<(), PeripheryError> {
        logger.contextualized(with: "version").debug(PeripheryVersion)
        let project: Project

        if configuration.guidedSetup {
            do {
                project = try GuidedSetup().perform()
            } catch let error as PeripheryError {
                return .failure(error)
            } catch {
                return .failure(.underlyingError(error))
            }
        } else {
            project = Project.identify()

            do {
                // Guided setup performs validation itself once the type has been determined.
                try project.validateEnvironment()
            } catch let error as PeripheryError {
                return .failure(error)
            } catch {
                return .failure(.underlyingError(error))
            }
        }

        let updateChecker = UpdateChecker()
        updateChecker.run()

        let results: [ScanResult]

        do {
            results = try block(project)
            let filteredResults = OutputDeclarationFilter().filter(results)
            let sortedResults = filteredResults.sorted { $0.declaration < $1.declaration }
            let output = try configuration.outputFormat.formatter.init().format(sortedResults)
            logger.info(output, canQuiet: false)
            
            let outputPath = Configuration.shared.outputPath
            if let outputPath = outputPath {
                let url = URL(fileURLWithPath: outputPath)
                try output.appendLineToURL(fileURL: url as URL)
//                let result = try String(contentsOf: url as URL, encoding: String.Encoding.utf8)
            }
            
      
            
            if filteredResults.count > 0,
                configuration.outputFormat.supportsAuxiliaryOutput {
                logger.info(
                    colorize("\n* ", .boldGreen) +
                        colorize("Seeing false positives?", .bold) +

                        colorize("\n - ", .boldGreen) +
                        "Periphery only analyzes files that are members of the targets you specify." +
                        "\n   References to declarations identified as unused may reside in files that are members of other targets, e.g test targets." +

                        colorize("\n - ", .boldGreen) +
                        "By default, Periphery does not assume that all public declarations are in use. " +
                        "\n   You can instruct it to do so with the " +
                        colorize("--retain-public", .bold) +
                        " option." +

                        colorize("\n - ", .boldGreen) +
                        "Periphery is a very precise tool, false positives often turn out to be correct after further investigation." +

                        colorize("\n - ", .boldGreen) +
                        "If it really is a false positive, please report it - https://github.com/peripheryapp/periphery/issues."
                )
            }

            updateChecker.notifyIfAvailable()

            if !filteredResults.isEmpty && configuration.strict {
                throw PeripheryError.foundIssues(count: filteredResults.count)
            }
        } catch let error as PeripheryError {
            return .failure(error)
        } catch {
            return .failure(.underlyingError(error))
        }

        return .success(())
    }
}

extension String {
    func appendLineToURL(fileURL: URL) throws {
         try (self + "\n").appendToURL(fileURL: fileURL)
     }

     func appendToURL(fileURL: URL) throws {
         let data = self.data(using: String.Encoding.utf8)!
         try data.append(fileURL: fileURL)
     }
 }

 extension Data {
     func append(fileURL: URL) throws {
         if let fileHandle = FileHandle(forWritingAtPath: fileURL.path) {
             defer {
                 fileHandle.closeFile()
             }
             fileHandle.seekToEndOfFile()
             fileHandle.write(self)
         }
         else {
             try write(to: fileURL, options: .atomic)
         }
     }
 }
