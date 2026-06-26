//
//  AddNoteSheet.swift
//  newtabnews
//
//  Created by Luiz Mello on 24/12/25.
//

import SwiftUI
import SwiftData

struct AddNoteSheet: View {
    let post: PostRequest
    let modelContext: ModelContext
    
    @Environment(\.dismiss) private var dismiss
    @State private var noteText = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(post.title ?? "")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                
                Section("Sua Anotação") {
                    TextEditor(text: $noteText)
                        .frame(minHeight: 150)
                }
            }
            .navigationTitle("Nova Anotação")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        saveNote()
                    }
                    .disabled(noteText.isEmpty)
                }
            }
        }
    }
    
    private func saveNote() {
        let note = Note(
            postId: post.stableKey,
            postTitle: post.title,
            content: noteText
        )
        
        modelContext.insert(note)
        modelContext.upsertSavedPost(from: post)
        
        let impact = UINotificationFeedbackGenerator()
        impact.notificationOccurred(.success)
        
        NotificationCenter.default.post(name: .notesUpdated, object: nil)
        
        GamificationManager.shared.trackNoteCreated(postId: post.stableKey)
        
        dismiss()
    }
}

