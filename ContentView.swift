//
//  ContentView.swift
//  volumeFixer
//
//  Created by WorkingMind on 6/1/26.
//

import SwiftUI
import MediaPlayer
import AVFoundation
//import AVSystemController
import Foundation
import UIKit

class BinauralBeatManager {
    
    private var audioEngine: AVAudioEngine!
    private var sourceNode: AVAudioSourceNode!
    private var rightSourceNode: AVAudioSourceNode!
    
    private let leftEqualizer = AVAudioUnitEQ(numberOfBands: 1)
    private let rightEqualizer = AVAudioUnitEQ(numberOfBands: 1)
    
    // 재생 상태 및 주파수 설정 변수
    public var isPlaying = false
    private var sampleRate: Double = 44100.0
    
    // 왼쪽 오른쪽 독립된 위상(Phase) 변수
    public var phaseLeft: Double = 100
    public var phaseRight: Double = 140
    
    public var volume: Float = 1.0
    public var boostDecibel: Float = 8.0
    
    init() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth])
            
            try session.setActive(true)
            
            
//            try audioEngine.start()
//            isPlaying = true
//            print("바이너럴 비트 재생 시작: L:\(leftHz)Hz / R:\(rightHz)Hz")
        }
        catch {
            print("오디오 엔진 시작 실패: \(error)")
        }
    }
    
    func startBinauralBeat(leftHz: Double = 100.0, rightHz: Double = 140.0) {
        
//        do {
//            let session = AVAudioSession.sharedInstance()
//            try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth])
//
//            try session.setActive(true)
//
//
////            try audioEngine.start()
////            isPlaying = true
//            print("바이너럴 비트 재생 시작: L:\(leftHz)Hz / R:\(rightHz)Hz")
//        }
//        catch {
//            print("오디오 엔진 시작 실패: \(error)")
//        }
        
        
        stop()
        
        
        
//        guard isPlaying else { return }
        
        audioEngine = AVAudioEngine()
        
        // 1. 실시간 오디오 렌더링 블록 정의 (수학적으로 사인파 생성)
        sourceNode = AVAudioSourceNode { [weak self] (_, _, frameCount, AudioBufferList) -> OSStatus in
                
            guard let self = self else { return noErr }
            
            let abl = UnsafeMutableAudioBufferListPointer(AudioBufferList)
            
            if let buffer = abl[0].mData?.assumingMemoryBound(to: Float.self) {
                let amplitude: Double = 0.8 // 이어폰 컴프레서 방지 마진 확보
                
                for frame in 0..<Int(frameCount)
                {
                    //실시간 수학적 사인파 연산
                    let sample = sin(self.phaseLeft) * amplitude
                    buffer[frame] = Float(sample)
                    
                    // 위상 증가 및 가속 회전 제어 (2 * pi * f / sampleRate)
                    self.phaseLeft += (2.0 * .pi * leftHz) / self.sampleRate
                    if self.phaseLeft > 2 * .pi { self.phaseLeft -= 2 * .pi }
                }
            }
            
            /* old code
            // 2채널(스테레오) 버퍼 가져오기 (0: 왼쪽, 1: 오른쪽)
            guard abl.count >= 2,
                  let bufferLeft = abl[0].mData?.assumingMemoryBound(to: Float.self),
                  let bufferRight = abl[1].mData?.assumingMemoryBound(to: Float.self) else {
                
                return noErr
            }
            
            //주파수에 따른 위상 증폭값 계산
            let phaseIncrementLeft = (2.0 * .pi * leftHz) / self.sampleRate
            let phaseIncrementRight = (2.0 * .pi * rightHz) / self.sampleRate
            
            // 각 프레임마다 사인파 값 계산 후 버퍼에 채우기
            for frame in 0..<Int(frameCount) {
                // 왼쪽 채널 사인파 (볼륨 volume 변수로 조절)
                bufferLeft[frame] = Float(sin(Float(self.phaseLeft)) * volume)
                self.phaseLeft += phaseIncrementLeft
                if self.phaseLeft >= 2.0 * .pi {
                    self.phaseLeft -= 2.0 * .pi
                }
                
                // 오른쪽 채널 사인파 (볼륨 volume 변수로 조절)
                
                bufferRight[frame] = Float(sin(Float(self.phaseRight)) * volume)
                self.phaseRight += phaseIncrementRight
                if self.phaseRight >= 2.0 * .pi {
                    self.phaseRight -= 2.0 * .pi
                }
                
            }
             */
            
            return noErr
        }
        
        // 2. 실시간 오른쪽 채널 사인파 발생기 정의
        rightSourceNode = AVAudioSourceNode { [weak self] (_, _, frameCount, AudioBufferList) -> OSStatus in
                
            guard let self = self else { return noErr }
            
            let abl = UnsafeMutableAudioBufferListPointer(AudioBufferList)
            
            if let buffer = abl[0].mData?.assumingMemoryBound(to: Float.self) {
                let amplitude: Double = 0.8 // 이어폰 컴프레서 방지 마진 확보
                
                for frame in 0..<Int(frameCount)
                {
                    //실시간 수학적 사인파 연산
                    let sample = sin(self.phaseRight) * amplitude
                    buffer[frame] = Float(sample)
                    
                    // 위상 증가 및 가속 회전 제어 (2 * pi * f / sampleRate)
                    self.phaseRight += (2.0 * .pi * rightHz) / self.sampleRate
                    if self.phaseRight > 2 * .pi { self.phaseRight -= 2 * .pi }
                }
            }
            
            return noErr
        }
        
        
        
        guard let engine = audioEngine, let node = sourceNode, let node2 = rightSourceNode else { return }
        
        engine.attach(node)
        engine.attach(node2)
        engine.attach(leftEqualizer)
        engine.attach(rightEqualizer)
        
        // 4. 하드웨어 게인 증폭 세팅 (+ 24.0dB 파워업)
        configureAmplifier(leftEqualizer, hz: Float(leftHz), boostDecibel: boostDecibel)
        configureAmplifier(rightEqualizer, hz: Float(rightHz), boostDecibel: boostDecibel)
        
        // 5. 입출력 포맷 및 직렬 배선 세팅
        let monoFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        
        // [왼쪽 발생기] -> [왼쪽 증폭기] -> [믹서 입력(왼쪽 패닝)]
        engine.connect(node, to: leftEqualizer, format: monoFormat)
        engine.connect(leftEqualizer, to: engine.mainMixerNode, format: monoFormat)
        
        // [오른쪽 발생기] -> [오른쪽 증폭기] -> [믹서입력(오른쪽 패닝)]
        engine.connect(node2, to: rightEqualizer, format: monoFormat)
        engine.connect(rightEqualizer, to: engine.mainMixerNode, format: monoFormat)
        
        // 6. 하드웨어 물리 공간 분리(좌 -1.0/ 우 1.0)
        node.pan = -1.0
        node2.pan = 1.0
        
        // 7. 마스터 볼륨 최대 개방 및 엔진 가동
        engine.mainMixerNode.volume = volume
        
        do {
//            let session = AVAudioSession.sharedInstance()
//            try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth])
//
//            try session.setActive(true)
            
            try engine.start()
            isPlaying = true
            print("바이너럴 비트 재생 시작: L:\(leftHz)Hz / R:\(rightHz)Hz")
        }
        catch {
            print("오디오 엔진 시작 실패: \(error)")
        }
        
        
        /* old code
         
         
         
         
        // 2. 오디오 엔진에 노드 장착 및 포맷 설정 (스테레오 필수)
        
        engine.attach(node)
        
        let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        engine.connect(node, to: engine.mainMixerNode, format: stereoFormat)
        
        // 3. 오디오 오디오 세션 활성화 및 엔진 시작
        
        do {
//            let session = AVAudioSession.sharedInstance()
//            try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth])
//
//            try session.setActive(true)
            
            try engine.start()
            isPlaying = true
            print("바이너럴 비트 재생 시작: L:\(leftHz)Hz / R:\(rightHz)Hz")
        }
        catch {
            print("오디오 엔진 시작 실패: \(error)")
        }
        
         */
    }
    
    /// EQ 노드를 볼륨 게인 증폭기로 세팅하는 헬퍼 함수
    private func configureAmplifier(_ eqNode: AVAudioUnitEQ, hz: Float, boostDecibel: Float)
    {
        let filterBand = eqNode.bands[0]
        filterBand.filterType = .parametric
        filterBand.frequency = hz
        filterBand.bandwidth = 2.0
        filterBand.bypass = false
        filterBand.gain = boostDecibel
    }
    
    func stop() {
        
        if audioEngine?.isRunning == true
        {
            audioEngine?.stop()
            
            //메모리 누수 방지를 위해 노드 연결 해제 및 초기화
            if let leftNode = sourceNode {
                audioEngine.detach(leftNode)
            }
            if let rightNode = rightSourceNode {
                audioEngine.detach(rightNode)
            }
            
            audioEngine = nil
    //        sourceNode = nil
    //        rightSourceNode = nil
            isPlaying = false
            phaseLeft = 0.0
            phaseRight = 0.0
            print("재생 중지")
        }
        
        
        
        
    }
    
    
    
    
    
    
}

class CallVolumeObserver: NSObject {
    
    // 싱글톤 패턴 적용
    static let shared = CallVolumeObserver()
    
    // 외부에서 현재 통화 볼륨 값을 받아볼 수 있도록 클로저 제공
    var onCallVolumeChanged: ((Float) -> Void)?
    
    private override init()
    {
        super.init()
    }
    
    /// 통화볼륨 모니터링 시작
    func startObserving() {
        // 1. 프라이빗 알림 이름 정의
        let notificationName = NSNotification.Name("AVSystemController_SystemVolumeDidChangeNotification")
        
        // 2. 알림센터에 옵저버 등록
        NotificationCenter.default.addObserver(self, selector: #selector(systemVolumeChanged(_:)), name: notificationName, object: nil)
        
        print(" 통화 볼륨 모니터링이 시작되었습니다.")
    }
    
    /// 통화 볼륨 모니터링 중지
    func stopObserving() {
        
        let notificationName = NSNotification.Name("AVSystemController_SystemVolumeDidChangeNotification")
        
        NotificationCenter.default.removeObserver(self, name: notificationName, object: nil)
        
        print("통화 볼륨 모니터링이 중지되었습니다.")
        
    }
    
    func getCurrentCallVolume() -> Float? {
        // 1. 프라이빗 클래스 로드 및 AnyObject 캐스팅
        guard let avcClass = NSClassFromString("AVSystemController") as AnyObject? else {
            return nil
        }
        
        let sharedSelector = Selector(("sharedAVSystemController"))
        guard avcClass.responds(to: sharedSelector) else { return nil }
        
        guard let unmanagedResult = avcClass.perform(sharedSelector) else {
            return nil
        }
        let controller = unmanagedResult.takeUnretainedValue() as AnyObject
        
        let getVolumeSelector = Selector(("getVolume:forCategory:"))
        guard controller.responds(to: getVolumeSelector) else {
            return nil
        }
        
        var targetVolume : Float = 0.0
        let categoryName = "VoiceCall"
        
        let methodIMP = controller.method(for: getVolumeSelector)
        
        typealias GetVolumeFunc = @convention(c) (AnyObject, Selector, UnsafeMutablePointer<Float>, AnyObject) -> Bool
        
        let function = unsafeBitCast(methodIMP, to: GetVolumeFunc.self)
        
        let isSuccess = function(controller, getVolumeSelector, &targetVolume, categoryName as AnyObject)
        
        if isSuccess {
            print("통화 볼륨 값: \(targetVolume)")
            return targetVolume
        }
        else
        {
            print("통화 볼륨 값을 읽어오는데 실패했습니다.")
            return nil
        }
    }
    
    /// 알림 콜백 함수
    @objc private func systemVolumeChanged(_ notification: Notification)
    {
        // userInfo 딕셔너리가 비었으면 종료
        guard let userInfo = notification.userInfo else { return }
        
        // 3. 프라이빗 딕셔너리 Key 정의
        // AVSystemController_AudioVolumeCategoryParameter
        let categoryKey = "AVSystemController_AudioVolumeCategoryParameter"
        // AVSystemController_AudioVolumeNotificationParameter
        let volumeKey = "AVSystemController_AudioVolumeNotificationParameter"
        
        // 4. 현재 변경된 볼륨의 카테고리 확인
        if let category = userInfo[categoryKey] as? String, category == "VoiceCall" {
            
            // 5. VoiceCall(통화 볼륨)인 경우에만 볼륨 값 추출(0.0 ~ 1.0)
            if let volumeValue = userInfo[volumeKey] as? Float {
                print(" 통화 볼륨(VoiceCall)이 변경됨: \(volumeValue)")
                
                // 메인 스레드에서 클로저 전달(UI 업데이트 안정성 확보)
                DispatchQueue.main.async {
                    self.onCallVolumeChanged?(volumeValue)
                }
            }
        }
    }
    
    deinit {
        stopObserving()
    }
}

class VolumeController: UIViewController {
    
    private let volumeView = MPVolumeView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 아래 구문처럼 해야, 실제 시스템의 볼륨조절이 제대로 이루어진다. 이 구절을 넣고 테스트해보면, 볼륨키로 볼륨을 올렸을 때에 다시 제로로 자동으로 조절되는 것을 볼 수 있다.
        volumeView.frame = CGRect(x: -100, y: -100, width: 1, height: 1)
        volumeView.clipsToBounds = true
        view.addSubview(volumeView)
    }
    
    // 시스템 볼륨 설정 함수
    func setSystemVolume(to value: Float) {
        
        // 슬라이더를 찾아서 값을 변경 (0.0 ~ 1.0)
        if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            DispatchQueue.main.async {
                slider.setValue(value, animated: true)
            }
        }
    }
    
    func getSystemVolume() -> Float {
//        let volumeView = MPVolumeView()
        
        var result :  Float = 1.0
        
        // 슬라이더를 찾아서 값을 변경 (0.0 ~ 1.0)
        if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            
            
            
            DispatchQueue.main.async {
                if slider.value == 0.0 {
                    result = 0.0
                }
            }
            
            if slider.value == 0.0
            {
                return slider.value
            }
            else
            {
                return slider.value
            }
        }
        
        return 1.0
    }
    
    // 이 함수는 벨소리 볼륨까지 조절하는 함수로 앱스토어 심사시 반드시 Reject되는 비공식 프라이빗 API이다.
    func setBellSoundVolume(to value: Float) {
        
        //NSClassFromString을 이용해 숨겨진 클래스에 접근
        if let AVC_Class = NSClassFromString("AVSystemController") as AnyObject? {
            // 1. sharedAVSystemController 싱글톤 객체 가져오기
            let sharedSelector = Selector(("sharedAVSystemController"))
            
            if AVC_Class.responds(to: sharedSelector) {
                // perform 결과를 Unmanaged<AnyObject>로 명시적으로 캐스팅
                if let unmanagedController = AVC_Class.perform(sharedSelector) {
                    let controller = unmanagedController.takeUnretainedValue()
                    
                    // 2. 볼륨 변경 세팅
                    let setVolumeSelector = Selector(("setVolume:forCategory:"))
                    
                    // 프라이빗 메서드를 안전하게 호출하기 위해 respond(to:) 확인 후 호출
                    if (controller as AnyObject).responds(to: setVolumeSelector) {
                        // Swift의 perform은 객체(AnyObject)만 인자로 받을 수 있으므로,
                        // Float 값인 0.0을 NSNumber로 감싸서 전달해야 합니다.
                        let volumeTarget = NSNumber(value: value)
                        let categoryName = "Ringtone"
                        
                        _ = (controller as AnyObject).perform(setVolumeSelector, with: volumeTarget, with: categoryName)
                        print("벨소리 볼륨 제어 명령이 성공적으로 전달 되었습니다.")
                    }
                }
            }
        }
    }
    
    static func adjustMicrophoneVolume() {
        
        
    }
}


struct ContentView: View {
    
    @State var beatManager = BinauralBeatManager()
    @State var stopOperation : Bool = true
    @State var timer : Timer?
    @State var repeatOnAndOff : Bool = true
    @State var onAndOffTimer: Timer?
    
    @State var volumeController = VolumeController()
    
    @State var currentCallVolumeNumber: Int = -100
    
    func volumeZeroFix() {
        
        DispatchQueue.main.async {
            
            if volumeController.getSystemVolume() == 0.0
            {
                print("Volume is currently Zero already")
                
                volumeController.setSystemVolume(to: 0.0)
                volumeController.setBellSoundVolume(to: 0.0)
                
                if timer == nil || timer?.isValid == false
                {
                    timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { Timer in
                        
                        self.volumeZeroFix()
                    }
                }
                
                return
            }
            else
            {
                if stopOperation == false {
                    stopOperation = true
//                            beatManager.stop()
                    
                }
                
                volumeController.setSystemVolume(to: 0.0)
                volumeController.setBellSoundVolume(to: 0.0)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0)
                {
                    beatManager.startBinauralBeat(leftHz: 0.01, rightHz: 0.01)
                    
                    stopOperation = false
                    volumeZeroFix()
                }
            }
            
            timer?.invalidate()
            timer = nil
            
            volumeController.setSystemVolume(to: 0.0)
            volumeController.setBellSoundVolume(to: 0.0)
            
            if stopOperation == false
            {
                print("Volume is currently Zero")
                volumeZeroFix()
            }
            else
            {
                stopOperation = true
            }
        }
        
    }
    
    func volumehalfFix() {
        
        DispatchQueue.main.async {
            
            volumeController.setSystemVolume(to: 0.5)
            volumeController.setBellSoundVolume(to: 0.5)
            
            if stopOperation == false
            {
                volumehalfFix()
            }
            else
            {
                stopOperation = true
            }
        }
        
    }
    
    func adjustMicrophoneVolume() {
        
//        beatManager.
        
    }
    
    
    
    var body: some View {
        VStack {
            
            Text("Volume Fixer")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(Color.blue)
            
            Text("For Security")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Color.blue)
                .padding(.bottom, 10)
            
            // 통화 볼륨 값은 아직까진 가져오지 못하나 통화를 임의로 하고 볼륨을 최대로 내리면 되므로 그렇게 하도록 표시함
//            Button {
//                self.currentCallVolumeNumber = CallVolumeObserver.shared.getCurrentCallVolume() == nil ? -1: Int(CallVolumeObserver.shared.getCurrentCallVolume()! * 100)
//            } label: {
//                Text("Current Call Volume: \(currentCallVolumeNumber)")
//                    .font(.headline)
//                    .font(Font.callout.monospacedDigit())
//                    .foregroundStyle(Color.orange)
//                    .padding(.all, 10)
//                    .background(Color.blue)
//                    .cornerRadius(10)
//                    .padding(.all, 10)
//            }

            
            
            Text("전화 볼륨을 끄려면, 전화를 받은 뒤, 전화를 끊기 전에 아이폰 측면의 볼륨버튼으로 전화 볼륨을 최소가 되도록(0으로는 할 수 없음) 바꾼 뒤에 끄십시오. 전화 볼륨은 가장 최근의 전화받을 때의 볼륨 상태를 기억하게 되어 있습니다.")
                .font(.headline)
                .font(Font.callout.monospacedDigit())
                .foregroundStyle(Color.mint)
                .padding(.bottom, 40)
            
            Button {
                
                if stopOperation == false {
                    stopOperation = true
//                    beatManager.stop()
                    return
                }
                
                beatManager.startBinauralBeat(leftHz: 0.01, rightHz: 0.01)
                
                stopOperation = false
                volumeZeroFix()
                
            } label: {
                Text(stopOperation ? "Start System Volume Zero" : "Stop")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                    .padding()
            }
            
            Button {
                
                if stopOperation == false {
                    stopOperation = true
//                    beatManager.stop()
                    return
                }
                
                beatManager.startBinauralBeat(leftHz: 300, rightHz: 0.01)
                
                stopOperation = false
                volumehalfFix()
                
            } label: {
                Text(stopOperation ? "Test System Volume half" : "Stop")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                    .padding()
            }
            
            // 이 기능은 해킹당한 것으로 보이는 폰에서 볼륨을 줄이다가 보면 대략 한 1분 후쯤부터 서서히 잡음이 생기는 현상을 막기 위해
            // 자동으로 스위치를 on/off 해주는 타이머를 달아서 듣기 싫은 잡음이 들려오기 전에 볼륨 줄이는 옵션을 껐다 켜주는 기능이다.
            Toggle(isOn: $repeatOnAndOff) {
                
                Text("Repeat On and Off")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
            }
            .onChange(of: repeatOnAndOff) { newValue in
                if newValue {
                    
                    onAndOffTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true, block: { Timer in
                        
                        print("on and off Timer executed")
                        
                        if stopOperation == false {
                            stopOperation = true
//                            beatManager.stop()
                            
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0)
                        {
                            beatManager.startBinauralBeat(leftHz: 0.01, rightHz: 0.01)
                            
                            stopOperation = false
                            volumeZeroFix()
                        }
                        
                    })
                }
                else {
                    onAndOffTimer?.invalidate()
                    onAndOffTimer = nil
                }
            }

        }
        .padding()
        .onAppear {
            
            CallVolumeObserver.shared.startObserving()
            
            // 1. 통화 볼륨 변경시 실행할 동작(클로저) 등록
            CallVolumeObserver.shared.onCallVolumeChanged = { currentCallVolume in
                // currentCallVolume은 0.0(최소) ~ 1.0(최대) 사이의 값입니다.
                print("현재 저장된 통화 볼륨 수치: \(Int(currentCallVolume * 100))%")
                
                self.currentCallVolumeNumber = Int(currentCallVolume * 100)
            }
            
            self.currentCallVolumeNumber = CallVolumeObserver.shared.getCurrentCallVolume() == nil ? -1: Int(CallVolumeObserver.shared.getCurrentCallVolume()! * 100)
            
            if stopOperation == false {
                stopOperation = true
//                beatManager.stop()
                return
            }
            
            beatManager.startBinauralBeat(leftHz: 0.01, rightHz: 0.01)
            
            stopOperation = false
            volumeZeroFix()
            
            // ToDo: if iphone 11이면 타이머를 걸어 특정 시간 지난 후에 위 코드를 다시 실행하도록 주기적으로 반복하도록 한다.
            
            if repeatOnAndOff {
                
                onAndOffTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true, block: { Timer in
                    
                    print("on and off Timer executed")
                    
                    if stopOperation == false {
                        stopOperation = true
//                            beatManager.stop()
                        
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0)
                    {
                        beatManager.startBinauralBeat(leftHz: 0.01, rightHz: 0.01)
                        
                        stopOperation = false
                        volumeZeroFix()
                    }
                    
                })
            }
            else {
                onAndOffTimer?.invalidate()
                onAndOffTimer = nil
            }
        }
        .onChange(of: volumeController.getSystemVolume()) { newValue in
            if newValue != 0.0
            {
                if stopOperation == false {
                    stopOperation = true
    //                beatManager.stop()
                    return
                }
                
                volumeController.setSystemVolume(to: 0.0)
                volumeController.setBellSoundVolume(to: 0.0)
                
                beatManager.startBinauralBeat(leftHz: 0.01, rightHz: 0.01)
                
                stopOperation = false
                volumeZeroFix()
            }
        }
    }
}

#Preview {
    ContentView()
}
