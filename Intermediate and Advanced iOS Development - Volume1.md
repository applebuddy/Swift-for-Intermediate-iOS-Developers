## Intermediate and Advanced iOS Development - Volume1



### 4. Managing Loading States in SwiftUI App

```swift
import SwiftUI

struct Product: Decodable, Identifiable {
    let id = UUID()
    let name: String
    
    private enum CodingKeys: CodingKey {
        case name
    }
}

enum SampleError: Error, LocalizedError {
    case operationFailed

    var errorDescription: String? {
        switch self {
        case .operationFailed:
            return NSLocalizedString("The operation failed. Please try again later.", comment: "Operation Failed Error")
        }
    }
}

// 열거형으로 Loading 상태를 관리
enum LoadingState<T> {
    case loading
    case success(T)
    case failure(Error)
}

/// 제네릭 리스트와 함께 정의된 LoadingStateView
struct LoadingStateView<Content, T>: View where Content: View {
    let state: LoadingState<T>
    let content: (T) -> Content
    
    var body: some View {
        switch state {
            case .loading:
                ProgressView("Loading...")
            case .success(let data):
                content(data)
            case .failure(let error):
                Text(error.localizedDescription)
                    .foregroundColor(.red)
        }
    }
}

struct ContentView: View {
    // loading state 변경 시 UI 랜더링
    @State private var loadingState: LoadingState<[Product]> = .loading
    
    private func loadProducts() async {
        do {
            // 2초 간 loadingView가 노출 후 리스트 노출
            try await Task.sleep(for: .seconds(2.0))
            loadingState = .success(
                [Product(name: "Android"), Product(name: "iPhone")]
            )
        } catch {
            loadingState = .failure(error)
        }
    }
    
    var body: some View {
        LoadingStateView(state: loadingState) { products in
            List(products) { product in
                Text(product.name)
            }
        }
        .task {
            await loadProducts()
        }
    }
}

#Preview {
    ContentView()
}

```





### 3. Bring Reactivity to UIKit with @Observable

SwiftUI를 import 후, #Preview { ... } 매크로로 UIViewController 화면 preview 기능을 사용 가능

```swift
import Observation

// @Observable class 를 UIKit 에서도 사용 가능
@Observable
class AuthStatus {
  /// 해당 속성이 변경되면 UI가 랜더링 됩니다.
  var isLoggedIn: Bool = false
}

final class ViewController: UIViewController {
  private let authStatus = AuthStatus()
  
	private lazy var authStatusToggle: UISwitch = {
    let toggle = UISwitch()
    toggle.translatesAutoresizingMaskIntoConstraints = false
    toggle.isOn = false
    toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
    return toggle
  }()
  
 	lazy var loginStatusLabel: UILabel = {
    let label = UILabel()
    label.text = "Not logged in."
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()
  
  @objc private func toggleChanged(_ sender: UISwitch) {
    // toggle 시마다 상태 변경
    authStatus.isLoggedIn = sender.isOn
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()

		view.addSubview(authStatusToggle)
    view.addSubview(logInStatusLabel)

    // 중앙에 label, switch 배치
    NSLayoutConstraint.activate([
     authStatusToggle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
     authStatusToggle.centerYAnchor.constraint(equalTo: view.centerYAnchor),       
     loginStatusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),       
     loginStatusLabel.topAnchor.constraint(equalTo: authStatusToggle.bottomAnchor, constant: 20)       
    ])
  }
  
	override func updateProperties() {
    super.updateProperties()
    print("\(#function)")
    // iOS26 이상에서 지원하는 메서드
    // 일반적으로 updateProperties -> viewWillLayoutSubviews 순으로 호출
    loginStatusLabel.text = authStatus.isLoggedIn ? "Logged In": "Not Logged In"
  }
  
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    print("\(#function)")
    
    // 아래 코드로 toggle change가 발생할 때마다 viewWillLayoutSubviews 호출해서 UI 업데이트 가능
    // -> iOS26+ updateProperties method 에서 대신 실행해도 됨
    // loginStatusLabel.text = authStatus.isLoggedIn ? "Logged In": "Not Logged In"
  }
}

#Preview {
  ViewController() // Preview 사용 가능
}
```
