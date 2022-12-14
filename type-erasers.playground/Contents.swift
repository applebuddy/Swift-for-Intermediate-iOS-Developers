//: A UIKit based Playground for presenting user interface

// MARK: 65. Type Erasers in Swift
// Type Eraser는 보편적인 케이스에 사용하는 것은 아니지만, 아래와 같이 같은 프로토콜을 채택하는 배열을 한번에 관리하거나 할때 AnyConfigurable과 같은 클래스를 만들어서 사용할 수 있다.

import UIKit
import PlaygroundSupport
import Darwin

protocol ConfigurableCell {
  // associatedtype Model을 선언해서 ConfigurableCell을 채택한 객체가 개별적으로 Model의 타입을 정의해서 그에 맞게 protocol을 준수하는 configure 메서드를 사용할 수 있다.
  associatedtype Model
  func configure(_ model: Model)
  func identifier() -> String
}

struct User {
  let name: String
}

class StudentCell: ConfigurableCell {
  typealias Model = User
  var model: Model?
  func configure(_ model: Model) {
    self.model = model
  }
  
  func identifier() -> String {
    self.model?.name ?? ""
  }
}

class StaffCell: ConfigurableCell {
  typealias Model = User
  var model: Model?
  func configure(_ model: Model) {
    self.model = model
  }
  
  func identifier() -> String {
    self.model?.name ?? ""
  }
}

// - error : Protocol 'ConfigurableCell' can only be used as a generic constraint because it has Self or associated type requirements
// let cells: [ConfigurableCell] = [StudentCell(), StaffCell()]
/*
class AnyConfigurable: ConfigurableCell {
  typealias Model = Any
  private let configureCellClosure: (Any) -> Void
  init<T: ConfigurableCell>(_ configurableCell: T) {
    configureCellClosure = { model in
      guard let model = model as? T.Model else { return }
      configurableCell.configure(model)
    }
  }
  
  func configure(_ model: Any) {
    configureCellClosure(model)
  }
}

let cells = [AnyConfigurable(StudentCell()), AnyConfigurable(StaffCell())]
*/
// StudentCell, StaffCell이 ConfigurableCell을 채택하고 있지만, 채택한 프로토콜타입을 메서드의 반환타입으로 사용할 수 없다. 본 타입을 숨기고 반환할 수 없을까?
/*
// 컴파일 에러 발생
func getStudentCell() -> ConfigurableCell {
  return StudentCell()
}
// 컴파일 에러 발생
func getStaffCell() -> ConfigurableCell {
  return StaffCell()
}
 */

// Opaque type으로 반환타입을 지정하면 상세 타입은 숨기고 반환이 가능하다.
func getStudentCell() -> some ConfigurableCell {
  let studentCell = StudentCell()
  studentCell.configure(User(name: "Monkey"))
  return studentCell
}

func getStaffCell() -> some ConfigurableCell {
  let staffCell = StaffCell()
  staffCell.configure(User(name: "Dog"))
  return staffCell
}
// Opaque type 반환 값을 통해 각자의 상세 identifier 값이 정상적으로 출력된다.
print("studentCellName : \(getStudentCell().identifier())")
print("staffCellName : \(getStaffCell().identifier())")

/*
let studentCell = getStudentCell() as? StudentCell
let staffCell = getStaffCell() as? StaffCell
print(studentCell?.model?.name)
print(staffCell?.model?.name)
 */


