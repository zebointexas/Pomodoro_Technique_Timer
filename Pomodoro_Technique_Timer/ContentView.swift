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
    // Work and Break Time Configuration
    @State private var workTimeTotal = 10      // 25 minutes work time
    @State private var breakTimeTotal = 5
    @State private var longBreakTimeTotal = 15
    
    @State private var currentWorkTime = 10
    @State private var currentBreakTime = 5
    
    // State Variables
    @State private var isWorking = true
    @State private var isTimerRunning = false
    @State private var isAlarmActive = false
    @State private var workSessionsCompleted = 0
    
    // Thumb Touch States
    @State private var leftThumbTouching = false
    @State private var rightThumbTouching = false
    
    // Prompt States
    @State private var showRestPrompt = false
    @State private var showRestConfirmation = false
    @State private var showStartConfirmation = false
    
    // Timer Management
    @State private var timer: Timer?
    @State private var alarmTimer: Timer?
    
    // Alarm Sound
    private let systemAlarmSoundID: SystemSoundID = 1005
    
    // App Lifecycle Tracking
    @Environment(\.scenePhase) private var scenePhase
    @State private var backgroundTime: Date?
    
    var body: some View {
        ZStack {
            // Background Color
            (isWorking ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                // Timer Mode Indicator
                Text(isWorking ? "Work Time" : "Break Time")
                    .font(.largeTitle)
                    .foregroundColor(isWorking ? .green : .orange)
                
                // Timer Display
                Text(timeString(time: isWorking ? currentWorkTime : currentBreakTime))
                    .font(.system(size: 70, design: .monospaced))
                    .foregroundColor(isAlarmActive ? .red : (isWorking ? .green : .orange))
                
                // Sessions Completed
                Text("Sessions Completed: \(workSessionsCompleted)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                // Alarm Active Indicator
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
                
                // Start Button (Only visible on initial launch or after reset)
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
                
                // Touch Circles with Specific Positioning
                HStack(spacing: 50) {
                    TouchCircle(isActive: leftThumbTouching, color: .blue, label: "Left Circle")
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    leftThumbTouching = true
                                    checkBothTouches()
                                }
                                .onEnded { _ in
                                    leftThumbTouching = false
                                    handleThumbRelease()
                                }
                        )
                    
                    TouchCircle(isActive: rightThumbTouching, color: .purple, label: "Right Circle")
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    rightThumbTouching = true
                                    checkBothTouches()
                                }
                                .onEnded { _ in
                                    rightThumbTouching = false
                                    handleThumbRelease()
                                }
                        )
                }
                .padding(.top, 40)
            }
            
            // Rest Prompt After 8 Sessions
            if showRestPrompt {
                RestPromptView(
                    onReset: {
                        showRestPrompt = false
                        showRestConfirmation = true
                    },
                    onExit: {
                        exit(0)
                    }
                )
            }
            
            // Rest Confirmation
            if showRestConfirmation {
                RestConfirmationView(
                    onYes: {
                        showRestConfirmation = false
                        showStartConfirmation = true
                    },
                    onNo: {
                        showRestConfirmation = false
                        showRestPrompt = true
                    }
                )
            }
            
            // Start Confirmation
            if showStartConfirmation {
                StartConfirmationView(
                    onYes: {
                        resetAll()
                        startWorkTimer()
                        showStartConfirmation = false
                    },
                    onNo: {
                        showStartConfirmation = false
                        showRestConfirmation = true
                    }
                )
            }
        }
        .onAppear {
            resetAll()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // Restore timer when app returns to foreground
                restoreTimerFromBackground()
            } else if newPhase == .background {
                // Save background time when app goes to background
                backgroundTime = Date()
                
                // Do NOT invalidate the timer during work session
                // Let the restoreTimerFromBackground handle the elapsed time
                if !isWorking {
                    timer?.invalidate()
                    currentBreakTime = (workSessionsCompleted % 4 == 0) ? longBreakTimeTotal : breakTimeTotal
                }
            }
        }
    }
    
    // Check Both Thumb Touches
    private func checkBothTouches() {
        if leftThumbTouching && rightThumbTouching && !isWorking {
            if isAlarmActive {
                stopAlarmSound()
                startBreakCountdown()
            }
        }
    }
    
    // Handle Thumb Release
    private func handleThumbRelease() {
        // If either thumb is released during break, reset break time
        if (!leftThumbTouching || !rightThumbTouching) && !isWorking {
            timer?.invalidate()
            alarmTimer?.invalidate()
            
            // Reset break time to full duration
            currentBreakTime = (workSessionsCompleted % 4 == 0) ? longBreakTimeTotal : breakTimeTotal
            
            isTimerRunning = false
            isAlarmActive = true
            startBreakAlarm()
        }
    }
    
    // Start Break Alarm
    private func startBreakAlarm() {
        timer?.invalidate()
        alarmTimer?.invalidate()
        
        isWorking = false
        isAlarmActive = true
        isTimerRunning = false
        
        // Determine break time based on session count (long break every 4 sessions)
        currentBreakTime = (workSessionsCompleted % 4 == 0) ? longBreakTimeTotal : breakTimeTotal
        
        alarmTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            if !leftThumbTouching || !rightThumbTouching {
                AudioServicesPlayAlertSound(systemAlarmSoundID)
            }
        }
    }
    
    // Stop Alarm Sound
    private func stopAlarmSound() {
        alarmTimer?.invalidate()
    }
    
    // Start Break Countdown
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
    
    // Start Work Timer
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
    
    // Reset All States
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
    
    // Restore Timer from Background
    private func restoreTimerFromBackground() {
        guard let backgroundTime = backgroundTime else { return }
        
        let timePassed = Int(Date().timeIntervalSince(backgroundTime))
        
        if isWorking {
            // Simulate the work timer running in the background
            currentWorkTime = max(0, currentWorkTime - timePassed)
            if currentWorkTime <= 0 {
                // Work session ended while in background, transition to break
                workSessionsCompleted += 1
                if workSessionsCompleted == 8 {
                    showRestPrompt = true
                } else {
                    startBreakAlarm()
                }
            } else {
                // Work session is still ongoing, restart the timer
                startWorkTimer()
            }
        } else {
            // Restore break alarm state
            startBreakAlarm()
        }
        
        self.backgroundTime = nil
    }
    
    // Time String Formatter
    private func timeString(time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// Touch Circle View
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

// Rest Prompt View
struct RestPromptView: View {
    var onReset: () -> Void
    var onExit: () -> Void
    
    var body: some View {
        VStack {
            Text("You've completed 8 consecutive work sessions.")
                .font(.headline)
            Text("Would you like to take a walk or rest?")
                .font(.subheadline)
                .multilineTextAlignment(.center)
            HStack(spacing: 20) {
                Button("Reset") {
                    onReset()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Button("Exit") {
                    onExit()
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

// Rest Confirmation View
struct RestConfirmationView: View {
    var onYes: () -> Void
    var onNo: () -> Void
    
    var body: some View {
        VStack {
            Text("Are you sure you've taken a walk or rested?")
                .font(.headline)
                .multilineTextAlignment(.center)
            HStack(spacing: 20) {
                Button("Yes") {
                    onYes()
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Button("No") {
                    onNo()
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

// Start Confirmation View
struct StartConfirmationView: View {
    var onYes: () -> Void
    var onNo: () -> Void
    
    var body: some View {
        VStack {
            Text("Are you ready to dive back in and start the next session?")
                .font(.headline)
                .multilineTextAlignment(.center)
            HStack(spacing: 20) {
                Button("Yes") {
                    onYes()
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Button("No") {
                    onNo()
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
