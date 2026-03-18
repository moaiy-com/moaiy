import SwiftUI

struct ContentView: View {
    @StateObject private var testRunner = SandboxTestRunner()
    @State private var testOutput: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Moaiy Sandbox Tests")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            ScrollView {
                Text(testOutput)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color.black.opacity(0.1))
            .cornerRadius(8)
            
            HStack(spacing: 20) {
                Button("Run All Tests") {
                    Task {
                        await runTests()
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Button("Clear Output") {
                    testOutput = ""
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .frame(width: 800, height: 600)
        .padding()
    }
    
    private func runTests() async {
        testOutput = "Starting sandbox tests...\n\n"
        
        // Capture print output
        let originalPrint = { (text: String) in
            DispatchQueue.main.async {
                self.testOutput += text + "\n"
            }
        }
        
        // Run tests
        await testRunner.runAllTests()
        
        testOutput += "\n✅ Tests completed! Check Console for detailed output."
    }
}

#Preview {
    ContentView()
}
