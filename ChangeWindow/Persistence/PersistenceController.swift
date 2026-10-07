import CoreData

final class PersistenceController {
    let container: NSPersistentContainer
    private(set) var loadError: Error?

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "ChangeWindow", managedObjectModel: ChangeWindowDataModel.shared)

        if let description = container.persistentStoreDescriptions.first {
            if inMemory {
                description.url = URL(fileURLWithPath: "/dev/null")
            }
            description.setOption(FileProtectionType.completeUntilFirstUserAuthentication as NSObject,
                                  forKey: NSPersistentStoreFileProtectionKey)
        }

        container.loadPersistentStores { [weak self] _, error in
            if let error { self?.loadError = error }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
