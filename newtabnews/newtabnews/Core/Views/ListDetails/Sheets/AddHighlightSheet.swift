//
//  AddHighlightSheet.swift
//  newtabnews
//
//  Created by Luiz Mello on 24/12/25.
//

import SwiftUI
import SwiftData

struct AddHighlightSheet: View {
    let post: PostRequest
    let modelContext: ModelContext
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedText = ""
    @State private var highlightNote = ""
    @State private var selectedColor = HighlightColor.yellow
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(post.title ?? "")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                
                Section("Selecione o Texto") {
                    TextEditor(text: $selectedText)
                        .frame(minHeight: 100)
                        .overlay(alignment: .topLeading) {
                            if selectedText.isEmpty {
                                Text("Cole ou digite o trecho que deseja destacar")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                }
                
                Section("Cor do Destaque") {
                    ForEach(HighlightColor.allCases, id: \.self) { color in
                        ColorPickerRow(
                            color: color,
                            isSelected: selectedColor == color,
                            onSelect: { selectedColor = color }
                        )
                    }
                }
                
                Section("Nota (Opcional)") {
                    TextEditor(text: $highlightNote)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Novo Destaque")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        saveHighlight()
                    }
                    .disabled(selectedText.isEmpty)
                }
            }
        }
    }
    
    private func saveHighlight() {
        let highlight = Highlight(
            postId: post.stableKey,
            postTitle: post.title,
            highlightedText: selectedText,
            note: highlightNote.isEmpty ? nil : highlightNote,
            colorHex: selectedColor.rawValue,
            rangeStart: 0,
            rangeLength: selectedText.count
        )
        
        modelContext.insert(highlight)
        modelContext.upsertSavedPost(from: post)
        
        let impact = UINotificationFeedbackGenerator()
        impact.notificationOccurred(.success)
        
        NotificationCenter.default.post(name: .highlightsUpdated, object: nil)
        
        dismiss()
    }
}

struct ColorPickerRow: View {
    let color: HighlightColor
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Circle()
                    .fill(Color(hex: color.rawValue))
                    .frame(width: 24, height: 24)
                
                Text(color.displayName)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
}

