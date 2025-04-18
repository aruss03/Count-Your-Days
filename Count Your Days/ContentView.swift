//
//  ContentView.swift
//  Count Your Days
//
//  Created by Alex Russ on 4/17/25.
//

import SwiftUI

struct CountdownEvent: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var targetDate: Date
    var colorHex: String

    var color: Color {
        Color(hex: colorHex).opacity(0.3)
    }

    init(id: UUID = UUID(), title: String, targetDate: Date, color: Color) {
        self.id = id
        self.title = title
        self.targetDate = targetDate
        self.colorHex = color.toHex() ?? "#FFFFFF"
    }
}

struct ContentView: View {
    @State private var countdowns: [CountdownEvent] = []
    @State private var showingAddSheet = false
    @State private var editingEvent: CountdownEvent? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(sortedCountdowns()) { event in
                        CountdownCard(event: event)
                            .contextMenu {
                                Button("Edit") {
                                    editingEvent = event
                                }
                                Button(role: .destructive) {
                                    delete(event)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 20))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
                .padding()
            }
            .navigationTitle("Your Countdowns")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddCountdownView { newEvent in
                    countdowns.append(newEvent)
                }
            }
            .sheet(item: $editingEvent) { event in
                AddCountdownView(editingEvent: event) { updatedEvent in
                    if let index = countdowns.firstIndex(where: { $0.id == updatedEvent.id }) {
                        countdowns[index] = updatedEvent
                    }
                }
            }
        }
        .onAppear(perform: loadCountdowns)
        .onChange(of: countdowns) { _ in
            saveCountdowns()
        }
    }

    func sortedCountdowns() -> [CountdownEvent] {
        countdowns.sorted { $0.targetDate < $1.targetDate }
    }

    func delete(_ event: CountdownEvent) {
        countdowns.removeAll { $0.id == event.id }
    }

    func saveCountdowns() {
        if let encoded = try? JSONEncoder().encode(countdowns) {
            UserDefaults.standard.set(encoded, forKey: "countdowns")
        }
    }

    func loadCountdowns() {
        if let savedData = UserDefaults.standard.data(forKey: "countdowns"),
           let decoded = try? JSONDecoder().decode([CountdownEvent].self, from: savedData) {
            countdowns = decoded
        } else {
            countdowns = [
                CountdownEvent(title: "New TV Episode!", targetDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())!, color: .purple),
                CountdownEvent(title: "New Game Release", targetDate: Calendar.current.date(byAdding: .day, value: 15, to: Date())!, color: .mint)
            ]
        }
    }
}

struct CountdownCard: View {
    let event: CountdownEvent

    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: event.targetDate).day ?? 0
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(event.color)
                .frame(height: 120)
                .shadow(radius: 5)

            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(event.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(event.targetDate, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(daysRemaining)d")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal)
        }
    }
}

struct AddCountdownView: View {
    @Environment(\.dismiss) var dismiss
    @State private var title: String
    @State private var date: Date
    @State private var selectedColor: Color

    var editingEvent: CountdownEvent?
    var onSave: (CountdownEvent) -> Void

    init(editingEvent: CountdownEvent? = nil, onSave: @escaping (CountdownEvent) -> Void) {
        self.editingEvent = editingEvent
        _title = State(initialValue: editingEvent?.title ?? "")
        _date = State(initialValue: editingEvent?.targetDate ?? Date())
        _selectedColor = State(initialValue: Color(hex: editingEvent?.colorHex ?? "#A0F0D0"))
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Event Details")) {
                    TextField("Title", text: $title)
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }

                Section(header: Text("Card Color")) {
                    ColorPicker("Pick a color", selection: $selectedColor, supportsOpacity: false)

                    HStack {
                        Text("Preview swatch:")
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedColor.opacity(0.3))
                            .frame(width: 60, height: 30)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                    }
                }

                Section(header: Text("Preview")) {
                    CountdownCard(event: CountdownEvent(
                        id: editingEvent?.id ?? UUID(),
                        title: title.isEmpty ? "Event Title" : title,
                        targetDate: date,
                        color: selectedColor
                    ))
                }
            }
            .navigationTitle(editingEvent == nil ? "New Countdown" : "Edit Countdown")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updated = CountdownEvent(
                            id: editingEvent?.id ?? UUID(),
                            title: title,
                            targetDate: date,
                            color: selectedColor
                        )
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")

        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String? {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }

        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

#Preview {
    ContentView()
}
