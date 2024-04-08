import Cocoa
import Carbon.HIToolbox.Events

extension Data {
  func jsonDecoded<T: Decodable>() throws -> T {
    return try JSONDecoder().decode(T.self, from: self)
  }
}

extension String {
  func jsonDecoded<T: Decodable>() throws -> T {
    return try data(using: .utf8)!.jsonDecoded()
  }
}
