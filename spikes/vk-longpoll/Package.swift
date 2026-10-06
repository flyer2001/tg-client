// swift-tools-version: 6.0
// Throwaway spike (Research-First): контракт VK Bots Long Poll + отмена URLSession на Linux.
import PackageDescription

let package = Package(
    name: "vk-longpoll-spike",
    targets: [.executableTarget(name: "spike")]
)
