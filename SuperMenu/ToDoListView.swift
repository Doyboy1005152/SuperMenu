import SwiftUI

struct ToDoListView: View {
    @State private var tasks: [String] = []
    @State private var newTask: String = ""
    @AppStorage("shouldPromptBeforeTaskDeletion") var shouldPromptBeforeTaskDeletion: Bool = true
    @State private var showingDeleteDialog = false
    @State private var taskToDelete: String? = nil

    var body: some View {
        VStack(alignment: .leading) {
            Text("To-Do List")
                .font(.title)
                .padding(.leading)

            HStack {
                TextField("New task", text: $newTask)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        addTask()
                    }
                Button("Add") {
                    addTask()
                }
            }
            .padding()

            List {
                ForEach(tasks, id: \.self) { task in
                    HStack {
                        Button(action: {
                            taskToDelete = task
                            showingDeleteDialog = shouldPromptBeforeTaskDeletion
                            if !shouldPromptBeforeTaskDeletion {
                                tasks.removeAll(where: { $0 == task })
                            }
                        }) {
                            Label(task, systemImage: "checkmark.circle")
                        }
                        Button(action: {
                            taskToDelete = task
                            showingDeleteDialog = shouldPromptBeforeTaskDeletion
                            if !shouldPromptBeforeTaskDeletion {
                                tasks.removeAll(where: { $0 == task })
                            }
                        }) {
                            Image(systemName: "trash")
                        }
                        .foregroundStyle(.red)
                    }
                }
                .onDelete { indices in
                    tasks.remove(atOffsets: indices)
                    saveTasks()
                }
            }

            HStack {
                Spacer()
                Button("Clear All") {
                    tasks.removeAll()
                    saveTasks()
                }
                .padding()
            }
        }
        .padding()
        .frame(width: 400, height: 300)
        .onAppear {
            loadTasks()
        }
        .confirmationDialog(
            "Are you sure?",
            isPresented: $showingDeleteDialog,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let task = taskToDelete, let i = tasks.firstIndex(of: task) {
                    tasks.remove(at: i)
                    saveTasks()
                }
                taskToDelete = nil
            }
            Button("Delete and do not ask again") {
                shouldPromptBeforeTaskDeletion = false
            }
            Button("Cancel", role: .cancel) {
                taskToDelete = nil
            }
        }
    }

    func addTask() {
        let trimmed = newTask.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tasks.append(trimmed)
        newTask = ""
        saveTasks()
    }

    func saveTasks() {
        UserDefaults.standard.set(tasks, forKey: "ToDoListTasks")
    }

    func loadTasks() {
        if let saved = UserDefaults.standard.stringArray(forKey: "ToDoListTasks") {
            tasks = saved
        }
    }
}
