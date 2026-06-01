import Foundation

enum LocalSeedData {
    static var store: PetCareStore? {
        let now = Date()
        let calendar = Calendar.current
        let nextEightAM = nextDate(hour: 8, minute: 0, from: now, calendar: calendar)

        let catOne = Pet(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Cat One",
            caloriesPerDay: 220
        )

        let catTwo = Pet(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            name: "Cat Two",
            caloriesPerDay: 250
        )

        let events: [CareEvent] = [
            CareEvent(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                type: .food,
                petID: catOne.id,
                createdAt: now,
                startTime: calendar.date(byAdding: .hour, value: -2, to: now) ?? now,
                data: .food(
                    FoodEventData(
                        name: "Breakfast Dry Food",
                        foodType: .dry,
                        amount: 0.25,
                        unit: .cup,
                        calories: 95
                    )
                )
            )
        ]

        let savedOptions: [SavedEventOption] = [
            SavedEventOption(
                id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
                eventType: .food,
                data: .food(
                    SavedFoodData(
                        name: "Breakfast Dry Food",
                        unit: .cup,
                        caloriesPerUnit: 380,
                        foodType: .dry
                    )
                )
            )
        ]

        let reminders: [Reminder] = [
            Reminder(
                id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
                title: "Breakfast",
                mode: .reminderToEvent,
                eventType: .food,
                eventPetID: nil,
                eventData: .food(
                    FoodEventData(
                        name: "Breakfast Dry Food",
                        foodType: .dry,
                        amount: 0.25,
                        unit: .cup,
                        calories: 95
                    )
                ),
                dueAt: nextEightAM,
                dueStyle: .timestamp,
                schedule: ReminderSchedule(
                    recurrenceRule: .timesPerDay(
                        count: 1,
                        times: [DateComponents(hour: 8, minute: 0)]
                    ),
                    endDate: nil
                )
            )
        ]

        return PetCareStore(
            pets: [catOne, catTwo],
            events: events,
            savedOptions: savedOptions,
            reminders: reminders,
            settings: .defaults
        )
    }

    private static func nextDate(
        hour: Int,
        minute: Int,
        from date: Date,
        calendar: Calendar
    ) -> Date {
        let today = calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: date
        ) ?? date

        if today > date {
            return today
        }

        return calendar.date(byAdding: .day, value: 1, to: today) ?? date
    }
}
