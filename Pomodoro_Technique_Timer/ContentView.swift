import SwiftUI
import AVFoundation
import UserNotifications // 引入 UserNotifications 框架

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
    private let systemAlarmSoundID: SystemSoundID = 1013
    
    // App Lifecycle Tracking
    @Environment(\.scenePhase) private var scenePhase
    @State private var backgroundTime: Date?
    @State private var hasScheduledBreakNotification = false // 标记是否已调度休息阶段通知
    
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
            requestNotificationPermission() // 请求通知权限
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // Restore timer when app returns to foreground
                restoreTimerFromBackground()
            } else if newPhase == .background {
                // Save background time when app goes to background
                backgroundTime = Date()
                
                // 如果当前是休息阶段且未调度通知，调度通知
                if !isWorking && isAlarmActive && !hasScheduledBreakNotification {
                    scheduleBreakSessionNotification()
                    hasScheduledBreakNotification = true
                }
                
                // Do NOT invalidate the timer during work session
                // Let the restoreTimerFromBackground handle the elapsed time
                if !isWorking {
                    timer?.invalidate()
                    currentBreakTime = (workSessionsCompleted % 4 == 0) ? longBreakTimeTotal : breakTimeTotal
                }
            }
        }
    }
    
    // 请求通知权限
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("通知权限已授予")
            } else {
                print("通知权限被拒绝")
            }
        }
    }
    
    // 调度工作阶段结束时的通知
    private func scheduleWorkSessionNotification() {
        // 移除之前的通知（如果有）
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let content = UNMutableNotificationContent()
        content.title = "⚠️ 休息时间到了！"
        content.body = "警报正在响起，请回到 app 按住两个圆圈开始休息。"
        content.sound = UNNotificationSound.defaultCriticalSound(withAudioVolume: 1.0)
        
        // 设置触发时间为工作阶段的时长
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(currentWorkTime), repeats: false)
        
        // 创建通知请求
        let request = UNNotificationRequest(identifier: "workSessionEnd", content: content, trigger: trigger)
        
        // 添加通知
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("调度工作阶段通知失败: \(error)")
            } else {
                print("工作阶段通知已调度，将在 \(currentWorkTime) 秒后触发")
            }
        }
    }
    
    // 调度休息阶段通知
    private func scheduleBreakSessionNotification() {
        // 移除之前的通知（如果有）
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let content = UNMutableNotificationContent()
        content.title = "⚠️ 休息时间到了！"
        content.body = "警报正在响起，请回到 app 按住两个圆圈开始休息。"
        content.sound = UNNotificationSound.defaultCriticalSound(withAudioVolume: 1.0)
        
        // 设置触发时间为立即触发（1 秒后，因为 iOS 要求最小时间间隔）
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // 创建通知请求
        let request = UNNotificationRequest(identifier: "breakSessionStart", content: content, trigger: trigger)
        
        // 添加通知
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("调度休息阶段通知失败: \(error)")
            } else {
                print("休息阶段通知已调度，将在 1 秒后触发")
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
        
        // 如果 app 已经在后台，发送休息阶段通知
        if scenePhase == .background && !hasScheduledBreakNotification {
            scheduleBreakSessionNotification()
            hasScheduledBreakNotification = true
        }
        
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
        
        // 重置通知调度标记
        hasScheduledBreakNotification = false
        
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
        
        // 重置通知调度标记
        hasScheduledBreakNotification = false
        
        // 调度工作阶段结束的通知
        scheduleWorkSessionNotification()
        
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
        
        hasScheduledBreakNotification = false
        
        // 移除所有未决通知
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // Restore Timer from Background
    private func restoreTimerFromBackground() {
        guard let backgroundTime = backgroundTime else { return }
        guard isTimerRunning else {
            self.backgroundTime = nil
            return // 如果计时器未启动，则不执行任何恢复逻辑
        }
        
        let timePassed = Int(Date().timeIntervalSince(backgroundTime))
        
        if isWorking {
            // 计算在后台经过的时间，更新剩余工作时间
            currentWorkTime = max(0, currentWorkTime - timePassed)
            if currentWorkTime <= 0 {
                // 工作阶段在后台已经结束，进入休息阶段
                workSessionsCompleted += 1
                if workSessionsCompleted == 8 {
                    showRestPrompt = true
                } else {
                    startBreakAlarm()
                }
            } else {
                // 工作阶段尚未结束，继续计时而不是重置
                isTimerRunning = true
                timer?.invalidate() // 确保旧的 timer 被清理
                timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    if self.currentWorkTime > 0 {
                        self.currentWorkTime -= 1
                    }
                    
                    if self.currentWorkTime <= 0 {
                        self.workSessionsCompleted += 1
                        self.timer?.invalidate()
                        
                        if self.workSessionsCompleted == 8 {
                            self.showRestPrompt = true
                        } else {
                            self.startBreakAlarm()
                        }
                    }
                }
            }
        } else {
            // 恢复休息阶段的警报状态
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
