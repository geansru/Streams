import UIKit

class ChatRoomViewController: UIViewController {
  
  private lazy var chatRoom: ChatRoom = {
    let room = ChatRoomBuilder().build()
    room.delegate = self
    return room
  }()
  
  let tableView = UITableView()
  let messageInputBar = MessageInputView()
  
  var messages: [Message] = []
  
  var username = ""
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    chatRoom.start()
    chatRoom.joinChat(username: username)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    chatRoom.stop()
  }

}

// MARK - Message Input Bar

extension ChatRoomViewController: MessageInputDelegate {
  
  func sendWasTapped(message: String) {
    chatRoom.send(message: message)
  }
  
}

// MARK: - Protocol ChatRoomDelegate

extension ChatRoomViewController: ChatRoomDelegate {
  
  func received(message: Message) {
    insertNewMessageCell(message)
  }
  
}
