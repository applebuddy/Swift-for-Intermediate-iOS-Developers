# Intermediate and Advanced iOS Development - Volume1

## 12. Build a Debounce View Modifier in SwiftUI Without Combine (Async/Await Approach)

## 11. Fix Slow iOS Apps: Find Network Bottlenecks with Instruments + Caching

### 앱 네트워킹 간에 병목현상(bottle neck)을 확인하는 방법
- instruments에서 다양한 도구를 사용할 수 있다.
- Instruments 도구 중 Network를 사용 -> 좌상단 빨강원 버튼 클릭
  - 많은 네트워킹이 발생하면 Network 도구 그래프 내 스파이크가 발생 -> 네트워크 트래픽이 발생했다는 뜻
  - 스파이크 발생 위치를 드래그 하면, 해당 위치에서 발생한 http, 실행 코드 관련 네트워킹 로그를 확인 가능
  - 이미지 요청을 하는 경우, 스파이크 최소화를 위해 이미지 캐싱을 고려할 수 있음
    - ex) KingFisher, Nuke(Image Loading System), SDWebImage, NSCache 사용한 자체 캐싱로직 구현 등...
      - Nuke library를 사용해서 LukeUI import, SwiftUI 기반 UI 구성 시 LazyImage를 사용 가능 -> 이미지 캐싱 로직이 반영되면, 이미 요청한 이미지는 재요청하지 않으므로, 이미지 최초 로드 이후의 스파이크 발생을 최소화 할 수 있다.

## 10. How to Cache Images in Swift with NSCache and Async/Await

- SwiftUI 에서 기본 제공하는 AsyncImage View는 자체 캐싱 기능이 없으므로, 캐싱이 필요하다면 별도 구현이 필요함
- Caching 로직이 있는 ImageLoader 기반으로 동작하는 URLImage View 구현

#### EnvironmentValues extension

```swift
import SwiftUI

// @Entry Macro 활용해서 간단하게 EnvironmentValues 지정 가능
extension EnvironmentValues {
    @Entry var httpClient = HTTPClient()
    @Entry var imageLoader = ImageLoader()
}
```

#### URLImage View Implementation

```swift
import SwiftUI

/// image url 요청 시, 캐싱 로직이 포함된 Image View
struct URLImage: View {
    private let url: URL?
    @State private var image: UIImage?
    @Environment(\.imageLoader) private var imageLoader

    init(url: URL?, image: UIImage? = nil) {
        self.url = url
        self.image = image
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable() // Image는 resizable() 설정 후 frame 지정해야 크기가 변경 됨.
            } else {
                Image(systemName: "heart") // image가 없는 경우의 placeholder image 지정
            }
        }.task {
            // View 노출 시 url 기반 image 요청.
            // 한번 로드해서 캐싱했던 image는 재요청하지 않고 캐싱된 image 사용
            image = try? await imageLoader.fetchImage(url)
        }
    }
}

#Preview {
    URLImage(url: URL(string: "http://www.highoncoding.com/VegetableImages/carrots.png")!)
}
```

#### ImageLoader Implementation

```swift
import UIKit

struct ImageLoader {
    let httpClient: HTTPClient
    /// NSCache를 활용해서 Image 캐싱이 가능
    /// - key : imag eurl string
    /// - value : image to cache
    private static let cache = NSCache<NSString, UIImage>()

    init(httpClient: HTTPClient = HTTPClient()) {
        self.httpClient = httpClient
    }

    func fetchImage(_ url: URL?) async throws -> UIImage? {
        guard let url
        else {
            throw NetworkError.badUrl
        }

        // check in cache
        if let cachedImage = Self.cache.object(forKey: url.absoluteString as NSString) {
            // 캐시된 이미지가 있다면, 캐시한 이미지를 사용합니다.
            return cachedImage
        } else {
            // fetch the image if there's no cached image
            let resource = Resource(url: url, modelType: Data.self)
            let data = try await httpClient.load(resource)

            guard let image = UIImage(data: data)
            else {
                throw NetworkError.unsupportedImage
            }

            // store the image in the cache
            Self.cache.setObject(image, forKey: url.absoluteString as NSString)
            return image
        }
    }
}
```



## 9. How to implement infinite Scrolling in SwiftUI with Real API Data

- Infinite Scrolling : 스크롤할때 추가적으로 계속 데이터를 불러서 리스트를 보여주는 것
- environmentObject로 Store를 주입하는 방식으로 Screen 생성
- View가 노출될 때에 특정 async method 호출 가능한 SwiftUI View task 블럭을 통해 Screen View List 노출 시, 이후 스크롤로 마지막 product 노출 시에 productList 로드
  - 이미 요청한 마지막 product id라면, 더이상 로드하지 않음


```swift
import SwiftUI

@main
struct PlatziAppApp: App {
    var body: some Scene {
        WindowGroup {
            ProductListScreen()
                .environment(PlatziStore(httpClient: HTTPClient()))
        }
    }
}
```

- ProductListScreen List 노출 시 최초 products load, 이후 스크롤로 마지막 product 도달 시마다 추가 로드

```swift
import Foundation
import Observation

// PlatziStore를 environmentObject로 주입해서 API 요청에 사용

/// 서버로부터 받은 데이터가 디코딩될 DTO 모델
struct Product: Codable, Identifiable {
    let id: Int
    let title: String
    let price: Double
    let description: String
    let images: [String]
}

struct Constants {
    struct Urls {
        static func products(page: Int = 0, limit: Int = 10) -> URL {
            URL(string: "https://island-bramble.glitch.me/api/products?page=\(page)&limit=\(limit)")!
        }
    }
}

@MainActor
@Observable
class PlatziStore {
    let httpClient: HTTPClient
    var products: [Product] = []

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    func loadProducts(page: Int = 0, limit: Int = 10) async throws {

        // 요청에 필요한 url, query, responseType를 Resource로 정의 후 요청
        let resource = Resource(url: Constants.Urls.products(page: page, limit: limit), modelType: [Product].self)
        let newProducts = try await httpClient.load(resource)
        
        print(resource.url)
        
        // prevent duplicates based on product id

        products.append(contentsOf: newProducts)
    }
}
```

```swift
import SwiftUI

struct ProductListScreen: View {

    @Environment(PlatziStore.self) private var platziStore
    @State private var currentPage: Int = 1
    @State private var limit: Int = 10
    @State private var lastLoadedProductId: Int?

    private func loadMoreIfNeeded(currentProduct: Product) async {
        // 마지막 product에 도달했다면, 추가 product를 로드
        guard let lastProduct = platziStore.products.last,
              lastProduct.id == currentProduct.id,
              lastLoadedProductId != lastProduct.id // 더이상 로드할 product가 없다면, 추가 로드 불필요
        else {
            return
        }

        lastLoadedProductId = lastProduct.id
        currentPage += 1

        do {
            try await platziStore.loadProducts(page: currentPage, limit: limit)
        } catch {
            // TODO: 벼로 에러처리 고려 필요
            print(error.localizedDescription)
        }
    }

    var body: some View {
        List(platziStore.products) { product in
            VStack(alignment: .leading) {
                Text("\(product.id)")
                    .padding()
                    .background(.green)
                Text(product.title)
                Text(product.description)
                    .opacity(0.5)
            }
            .task {
                // 스크롤로 마지막 product 노출 시 호출
                await loadMoreIfNeeded(currentProduct: product)
            }
        }
        .task {
            do {
                // List 노출 시 1회 호출
                try await platziStore.loadProducts()
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}

#Preview {
    ProductListScreen()
        .environment(PlatziStore(httpClient: HTTPClient()))
}
```


## 7. Build a Modern Onboarding Flow in SwiftUI with Enums and Data Binding

- SwiftUI 기반의 Onboarding flow 구현하기

```swift
import SwiftUI

// 온보딩의 모든 단계를 정의
enum OnboardingStep: Int, CaseIterable, Identifiable {
    case graduation
    case income
    case expenses
    case review

    var id: Int { rawValue }
}

struct Onboarding {
    var graduation = Graduation()
    var income = Income()
    var expense = Expense()

    struct Graduation {
        var graduated: Bool = false
    }

    struct Income {
        var total: Double = 0.0
    }

    struct Expense {
        var total: Double = 0.0
    }
}


struct ReviewScreen: View {
    let onboarding: Onboarding

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review Your Information")
                .font(.title2)
                .bold()

            Divider()

            Group {
                Text("🎓 Graduated: \(onboarding.graduation.graduated ? "Yes" : "No")")
                Text("💰 Income: \(String(format: "$%.2f", onboarding.income.total))")
                Text("💸 Expenses: \(String(format: "$%.2f", onboarding.expense.total))")
            }
            .font(.headline)

            Spacer()
        }
        .padding()
    }
}

struct GraduationView: View {
    @Binding var graduation: Onboarding.Graduation

    var body: some View {
        Toggle("Graduated?", isOn: $graduation.graduated)
            .padding()
    }
}

struct IncomeView: View {
    @Binding var income: Onboarding.Income

    var body: some View {
        VStack {
            Text("Enter your total income:")
            TextField("Income", value: $income.total, format: .number)
                .keyboardType(.decimalPad)
                .padding()
        }
    }
}

struct ExpensesView: View {
    @Binding var expense: Onboarding.Expense

    var body: some View {
        VStack {
            Text("Enter your total expenses:")
            TextField("Expenses", value: $expense.total, format: .number)
                .keyboardType(.decimalPad)
                .padding()
        }
    }
}

struct OnboardingRootView: View {
    /// @State 변수들은 하위 View의 @Binding 변수들과 데이터바인딩 가능
    @State private var onboarding = Onboarding()
    @State private var currentStepIndex = 0

    var steps: [OnboardingStep] {
        OnboardingStep.allCases
    }

    var body: some View {
        VStack {
            TabView(selection: $currentStepIndex) {
                ForEach(steps) { step in
                    stepView(for: step)
                        .tag(step.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))


            Button {
                if currentStepIndex < steps.count - 1 {
                    withAnimation {
                        currentStepIndex += 1
                    }
                }
            } label: {
                Text(currentStepIndex == steps.count - 1 ? "Get started": "Next")
            }
            .buttonStyle(.borderedProminent)
            .padding([.horizontal, .bottom])


        }
        .foregroundStyle(.white)
        .background(.blue)
    }

    /// 각각의 온보딩 페이지에 데이터바인딩할 변수를 주입하면 View 생성
    @ViewBuilder
    private func stepView(for step: OnboardingStep) -> some View {
        switch step {
        case .graduation:
            GraduationView(graduation: $onboarding.graduation)
        case .income:
            IncomeView(income: $onboarding.income)
        case .expenses:
            ExpensesView(expense: $onboarding.expense)
        case .review:
            // Review 페이지에서는 각 페이지에 데이터바인딩되어있는 데이터들을 전체적으로 보여줌 (읽기만 함)
            ReviewScreen(onboarding: onboarding)
        }
    }
}

#Preview {
    OnboardingRootView()
}
```



## 6. Building the Car Price Prediction Model

## 5. Speed Up Xcode Previews with MockHTTPClient in SwiftUI

```swift
// 아래 프로토콜을 실제 Client, mock Client에서 채택해서 사용
protocol HTTPClientProtocol {
    func load<T: Codable>(_ resource: Resource<T>) async throws -> T
}

enum HTTPMethod {
    case get([URLQueryItem])
    case post(Data?)
    case delete
    case put(Data?)

    var name: String {
        switch self {
        case .get:
            return "GET"
        case .post:
            return "POST"
        case .delete:
            return "DELETE"
        case .put:
            return "PUT"
        }
    }
}

struct Resource<T: Codable> {
    let url: URL
    var method: HTTPMethod = .get([])
    var headers: [String: String]? = nil
    var modelType: T.Type
}

// MockHTTPClient를 사용해서 Preview 활용 가능
#Preview {
    NavigationStack {
        CategoryListScreen()
    }
    .environment(PlatziStore(httpClient: MockHTTPClient()))
}
```



## 4. Managing Loading States in SwiftUI App

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



## 3. Bring Reactivity to UIKit with @Observable

SwiftUI를 import 후, #Preview { ... } 매크로로 UIViewController 화면 preview 기능을 사용 가능

``` swift
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
