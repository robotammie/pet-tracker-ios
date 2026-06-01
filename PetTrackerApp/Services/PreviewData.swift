import Foundation

extension PetCareStore {
    static var preview: PetCareStore {
        if let localSeed = LocalSeedData.store {
            return localSeed
        }

        if let seed = SeedData.store {
            return seed
        }

        let luna = Pet(id: UUID(), name: "Luna", caloriesPerDay: 220)
        let miso = Pet(id: UUID(), name: "Miso", caloriesPerDay: 250)
        let now = Date()

        let events = [
            CareEvent(
                id: UUID(),
                type: .food,
                petID: luna.id,
                createdAt: now,
                startTime: Calendar.current.date(byAdding: .hour, value: -2, to: now) ?? now,
                endTime: nil,
                data: .food(FoodEventData(name: "Hills Dry", foodType: .dry, amount: 0.25, unit: .cup, calories: 95))
            ),
            CareEvent(
                id: UUID(),
                type: .food,
                petID: nil,
                createdAt: now,
                startTime: Calendar.current.date(byAdding: .hour, value: -4, to: now) ?? now,
                endTime: nil,
                data: .food(FoodEventData(name: "Shared Treats", foodType: .treat, amount: 2, unit: .ounce, calories: 30))
            ),
            CareEvent(
                id: UUID(),
                type: .medicine,
                petID: miso.id,
                createdAt: now,
                startTime: Calendar.current.date(byAdding: .hour, value: -6, to: now) ?? now,
                endTime: nil,
                data: .medicine(MedicineEventData(name: "Antibiotic", dosage: 1, unit: "tablet"))
            ),
            CareEvent(
                id: UUID(),
                type: .litter,
                petID: nil,
                createdAt: now,
                startTime: Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now,
                endTime: nil,
                data: .litter(LitterEventData())
            )
        ]

        let reminders = [
            Reminder(
                id: UUID(),
                title: "Give Miso antibiotic",
                mode: .reminderToEvent,
                eventType: .medicine,
                dueAt: Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now,
                dueStyle: .timestamp
            ),
            Reminder(
                id: UUID(),
                title: "Clean fountain",
                mode: .pureReminder,
                eventType: nil,
                dueAt: Calendar.current.date(byAdding: .hour, value: 5, to: now) ?? now,
                dueStyle: .dayOnly
            )
        ]

        return PetCareStore(
            pets: [luna, miso],
            events: events,
            reminders: reminders,
            settings: .defaults
        )
    }
}
