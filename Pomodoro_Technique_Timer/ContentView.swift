import SwiftUI

import AVFoundation



@main

struct PomodoroTimerApp: App {

    var body: some Scene {

        WindowGroup {

            ContentView()

        }

    }

}



struct ContentView: View {

    @State private var workTimeTotal = 10      // Work time in seconds

    @State private var breakTimeTotal = 5      // Regular break in seconds

    @State private var longBreakTimeTotal = 20 // Long break after 4 sessions

    @State private var currentWorkTime = 10

    @State private var currentBreakTime = 5

    

    @State private var isWorking = true

    @State private var isTimerRunning = false

    @State private var isAlarmActive = false

    @State private var workSessionsCompleted = 0

    @State private var showRestPrompt = false

    @State private var showRestConfirmation = false

    @State private var showStartConfirmation = false

    

    @State private var leftThumbTouching = false

    @State private var rightThumbTouching = false

    

    @State private var timer: Timer?

    @State private var alarmTimer: Timer?

    private let systemAlarmSoundID: SystemSoundID = 1005

    

    var body: some View {

        ZStack {

            (isWorking ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))

                .edgesIgnoringSafeArea(.all)

            

            VStack(spacing: 30) {

                Text(isWorking ? "Work Time" : "Break Time")

                    .font(.largeTitle)

                    .foregroundColor(isWorking ? .green : .orange)

                

                Text(timeString(time: isWorking ? currentWorkTime : currentBreakTime))

                    .font(.system(size: 70, design: .monospaced))

                    .foregroundColor(isAlarmActive ? .red : (isWorking ? .green : .orange))

                

                Text("Sessions Completed: \(workSessionsCompleted)")

                    .font(.subheadline)

                    .foregroundColor(.gray)

                

                if isAlarmActive {

                    VStack {

                        Text("⚠️ BREAK TIME ⚠️")

                            .foregroundColor(.red)

                            .font(.headline)

                        Text("Press both circles to start break")

                            .foregroundColor(.gray)

                            .font(.subheadline)

                    }

                }

                

                if !isTimerRunning && !isAlarmActive && !showRestPrompt {

                    Button(action: {

                        startWorkTimer()

                    }) {

                        Text("Start")

                            .foregroundColor(.white)

                            .padding()

                            .frame(width: 100)

                            .background(Color.green)

                            .cornerRadius(10)

                    }

                }

                

                HStack(spacing: 50) {

                    TouchCircle(isActive: leftThumbTouching, color: .blue, label: "Left Thumb")

                        .gesture(

                            DragGesture(minimumDistance: 0)

                                .onChanged { _ in

                                    if isAlarmActive || !isWorking {

                                        leftThumbTouching = true

                                        checkBothTouches()

                                    }

                                }

                                .onEnded { _ in

                                    if !isWorking {

                                        leftThumbTouching = false

                                        handleThumbRelease()

                                    }

                                }

                        )

                    

                    TouchCircle(isActive: rightThumbTouching, color: .purple, label: "Right Thumb")

                        .gesture(

                            DragGesture(minimumDistance: 0)

                                .onChanged { _ in

                                    if isAlarmActive || !isWorking {

                                        rightThumbTouching = true

                                        checkBothTouches()

                                    }

                                }

                                .onEnded { _ in

                                    if !isWorking {

                                        rightThumbTouching = false

                                        handleThumbRelease()

                                    }

                                }

                        )

                }

                .padding(.top, 40)

            }

            

            // Initial 8-session prompt

            if showRestPrompt {

                VStack {

                    Text("You've completed 8 consecutive work sessions.")

                        .font(.headline)

                    Text("Would you like to take a walk or rest?")

                        .font(.subheadline)

                        .multilineTextAlignment(.center)

                    HStack(spacing: 20) {

                        Button("Reset") {

                            showRestPrompt = false

                            showRestConfirmation = true

                        }

                        .padding()

                        .background(Color.blue)

                        .foregroundColor(.white)

                        .cornerRadius(10)

                        

                        Button("Exit") {

                            exit(0) // Exit the app

                        }

                        .padding()

                        .background(Color.red)

                        .foregroundColor(.white)

                        .cornerRadius(10)

                    }

                }

                .padding()

                .background(Color.white)

                .cornerRadius(15)

                .shadow(radius: 10)

            }

            

            // Rest confirmation

            if showRestConfirmation {

                VStack {

                    Text("Are you sure you've taken a walk or rested?")

                        .font(.headline)

                        .multilineTextAlignment(.center)

                    HStack(spacing: 20) {

                        Button("Yes") {

                            showRestConfirmation = false

                            showStartConfirmation = true

                        }

                        .padding()

                        .background(Color.green)

                        .foregroundColor(.white)

                        .cornerRadius(10)

                        

                        Button("No") {

                            showRestConfirmation = false

                            showRestPrompt = true

                        }

                        .padding()

                        .background(Color.red)

                        .foregroundColor(.white)

                        .cornerRadius(10)

                    }

                }

                .padding()

                .background(Color.white)

                .cornerRadius(15)

                .shadow(radius: 10)

            }

            

            // Start confirmation

            if showStartConfirmation {

                VStack {

                    Text("Are you ready to dive back in and start the next session?")

                        .font(.headline)

                        .multilineTextAlignment(.center)

                    HStack(spacing: 20) {

                        Button("Yes") {

                            resetAll()

                            startWorkTimer()

                            showStartConfirmation = false

                        }

                        .padding()

                        .background(Color.green)

                        .foregroundColor(.white)

                        .cornerRadius(10)

                        

                        Button("No") {

                            showStartConfirmation = false

                            showRestConfirmation = true

                        }

                        .padding()

                        .background(Color.red)

                        .foregroundColor(.white)

                        .cornerRadius(10)

                    }

                }

                .padding()

                .background(Color.white)

                .cornerRadius(15)

                .shadow(radius: 10)

            }

        }

        .onAppear {

            resetAll()

        }

    }

    

    private func checkBothTouches() {

        if leftThumbTouching && rightThumbTouching && !isWorking {

            if isAlarmActive {

                stopAlarmSound()

                startBreakCountdown()

            }

        }

    }

    

    private func handleThumbRelease() {

        if (!leftThumbTouching || !rightThumbTouching) && !isWorking {

            timer?.invalidate()

            alarmTimer?.invalidate()

            currentBreakTime = (workSessionsCompleted % 4 == 0) ? longBreakTimeTotal : breakTimeTotal

            isTimerRunning = false

            isAlarmActive = true

            startBreakAlarm()

        }

    }

    

    private func startBreakAlarm() {

        timer?.invalidate()

        alarmTimer?.invalidate()

        isWorking = false

        isAlarmActive = true

        isTimerRunning = false

        currentBreakTime = (workSessionsCompleted % 4 == 0) ? longBreakTimeTotal : breakTimeTotal

        

        alarmTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in

            if !leftThumbTouching || !rightThumbTouching {

                AudioServicesPlayAlertSound(systemAlarmSoundID)

            }

        }

    }

    

    private func stopAlarmSound() {

        alarmTimer?.invalidate()

    }

    

    private func startBreakCountdown() {

        isAlarmActive = false

        isTimerRunning = true

        

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in

            if leftThumbTouching && rightThumbTouching {

                if currentBreakTime > 0 {

                    currentBreakTime -= 1

                }

                if currentBreakTime <= 0 {

                    timer?.invalidate()

                    startWorkTimer()

                }

            } else {

                handleThumbRelease()

            }

        }

    }

    

    private func startWorkTimer() {

        timer?.invalidate()

        alarmTimer?.invalidate()

        isAlarmActive = false

        isWorking = true

        isTimerRunning = true

        currentWorkTime = workTimeTotal

        currentBreakTime = (workSessionsCompleted % 4 == 0) ? longBreakTimeTotal : breakTimeTotal

        leftThumbTouching = false

        rightThumbTouching = false

        

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in

            if currentWorkTime > 0 {

                currentWorkTime -= 1

            }

            if currentWorkTime <= 0 {

                workSessionsCompleted += 1

                timer?.invalidate()

                if workSessionsCompleted == 8 {

                    showRestPrompt = true

                } else {

                    startBreakAlarm()

                }

            }

        }

    }

    

    private func resetAll() {

        timer?.invalidate()

        alarmTimer?.invalidate()

        isWorking = true

        isTimerRunning = false

        isAlarmActive = false

        currentWorkTime = workTimeTotal

        currentBreakTime = breakTimeTotal

        leftThumbTouching = false

        rightThumbTouching = false

        workSessionsCompleted = 0

        showRestPrompt = false

        showRestConfirmation = false

        showStartConfirmation = false

    }

    

    private func timeString(time: Int) -> String {

        let minutes = time / 60

        let seconds = time % 60

        return String(format: "%02d:%02d", minutes, seconds)

    }

}



struct TouchCircle: View {

    var isActive: Bool

    var color: Color

    var label: String

    

    var body: some View {

        VStack {

            Circle()

                .fill(isActive ? color : color.opacity(0.3))

                .frame(width: 100, height: 100)

                .overlay(

                    Circle()

                        .stroke(color, lineWidth: 3)

                )

                .shadow(radius: 5)

            Text(label)

                .font(.caption)

                .foregroundColor(.gray)

        }

    }

}
