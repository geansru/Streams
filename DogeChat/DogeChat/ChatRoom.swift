import Foundation

protocol ChatRoomDelegate: AnyObject {
  func received(message: Message)
}

final class ChatRoom: NSObject {
  
  // MARK: - Private properties
  
  private let inputStream: InputStream
  private let outputStream: OutputStream
  private let maxReadLength: Int
  private var username: String?
  
  // MARK: - Internal properties
  
  weak var delegate: ChatRoomDelegate?
  
  // MARK: - Init
  
  init(inputStream: InputStream, outputStream: OutputStream, maxReadLength: Int) {
    self.inputStream = inputStream
    self.outputStream = outputStream
    self.maxReadLength = maxReadLength
  }
  
  func start() {
    inputStream.schedule(in: .current, forMode: .common)
    inputStream.open()
    inputStream.delegate = self
    
    outputStream.schedule(in: .current, forMode: .common)
    outputStream.open()
  }

  func stop() {
    inputStream.close()
    outputStream.close()
  }
  
  func joinChat(username: String) {
    let data = "iam:\(username)".data(using: .utf8)!
    
    self.username = username
    
    _ = data.withUnsafeBytes {
      guard let pointer = $0.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
        print("Error joining chat")
        return
      }
      outputStream.write(pointer, maxLength: data.count)
    }
  }
  
  func send(message: String) {
    let data = "msg:\(message)".data(using: .utf8)!
    
    _ = data.withUnsafeBytes {
      guard let pointer = $0.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
        print("Error joining chat")
        return
      }
      outputStream.write(pointer, maxLength: data.count)
    }
  }
  
}

extension ChatRoom: StreamDelegate {
  
  func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
    switch eventCode {
    case .hasBytesAvailable:
      guard let inputStream = aStream as? InputStream else {
        fatalError("Unexpected type of the stream")
      }
      readAvailableBytes(stream: inputStream)
      
    case .endEncountered:
      stop()
      
    case .errorOccurred:
      print("error occurred")
    case .hasSpaceAvailable:
      print("has space available")
    default:
      print("some other event...")
    }
  }
  
  private func readAvailableBytes(stream: InputStream) {
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxReadLength)
    
    while stream.hasBytesAvailable {
      let numberOfBytesRead = inputStream.read(buffer, maxLength: maxReadLength)
      if numberOfBytesRead < 0, let error = stream.streamError {
        print(error)
        break
      }
      
      // Construct the Message object
      if let message = processedMessageString(buffer: buffer, length: numberOfBytesRead) {
        delegate?.received(message: message)
      }
    }
  }
  private func processedMessageString(buffer: UnsafeMutablePointer<UInt8>,
                                      length: Int) -> Message? {
    guard let stringFromBuffer = String(bytesNoCopy: buffer, length: length, encoding: .utf8, freeWhenDone: true) else {
      return nil
    }
    
    let stringArray = stringFromBuffer.components(separatedBy: ":")
    guard let name = stringArray.first, let message = stringArray.last else {
        return nil
    }
    
    let messageSender: MessageSender = (name == self.username) ? .ourself : .someoneElse
    return Message(message: message, messageSender: messageSender, username: name)
  }
  
}

final class ChatRoomBuilder {
  
  // MARK: - Private types
  
  private enum Config {
    
    static var maxReadLength: Int { return 4096 }
    
    static var host: CFString { return "localhost" as CFString }
    
    static var port: UInt32 { return 80 }
    
  }
  
  // MARK: - Private properties
  
  private let port: UInt32
  private let host: CFString
  private let maxReadLength: Int
  
  // MARK: - Init
  
  init(maxReadLength: Int = Config.maxReadLength,
       host: CFString = Config.host,
       port: UInt32 = Config.port) {
    self.port = port
    self.host = host
    self.maxReadLength = maxReadLength
  }
  
  func build() -> ChatRoom {
    let (input, output) = makeStreams()
    return ChatRoom(inputStream: input, outputStream: output, maxReadLength: maxReadLength)
  }
  
  private func makeStreams() -> (InputStream, OutputStream) {
    var readStream: Unmanaged<CFReadStream>?
    var writeStream: Unmanaged<CFWriteStream>?
    
    CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                       Config.host,
                                       Config.port,
                                       &readStream,
                                       &writeStream)
    
    guard let input = readStream?.takeRetainedValue() else {
        fatalError("Unexpected nil instead of input stream.")
    }
    
    guard let output = writeStream?.takeRetainedValue()else {
      fatalError("Unexpected nil instead of output stream.")
    }
    
    return (input, output)
  }
}
