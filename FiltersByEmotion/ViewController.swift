//
//  ViewController.swift
//  FiltersByEmotion
//
//  Created by Larissa Uchoa on 18/06/21.
//

import UIKit
import ARKit
import AVFoundation

class ViewController: UIViewController {

    private let sceneView = ARSCNView(frame: UIScreen.main.bounds)

    private let model = try! VNCoreMLModel(for: NovoTeste2(configuration: MLModelConfiguration()).model)

    private let glassesPlane = SCNPlane(width: 0.13, height: 0.06)
    private let glassesNode = SCNNode()

    private let benPlane = SCNPlane(width: 0.15, height: 0.24)
    private let benNode = SCNNode()

    private var player: AVAudioPlayer?

    override func viewDidLoad() {
        super.viewDidLoad()

        guard ARWorldTrackingConfiguration.isSupported else { return }

        view.addSubview(sceneView)
        sceneView.delegate = self
        sceneView.showsStatistics = true

        setupMusic()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let configuration = ARFaceTrackingConfiguration()
        sceneView.session.run(configuration)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sceneView.session.pause()
    }

    private func updateGlasses(with index: Int) {
        let imageName = "glasses\(index)"
        glassesPlane.firstMaterial?.diffuse.contents = UIImage(named: imageName)
    }

    private func updateBen() {
        benPlane.firstMaterial?.diffuse.contents = UIImage(named: "ben10")
    }

    private func setupMusic() {
        let path = Bundle.main.path(forResource: "ben10.mp3", ofType: nil)!
        let url = URL(fileURLWithPath: path)

        do {
            player = try AVAudioPlayer(contentsOf: url)
            try AVAudioSession.sharedInstance().setCategory(.playback)
        } catch {
            print(error)
        }
    }
}

extension ViewController: ARSCNViewDelegate {

    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let device = sceneView.device else { return nil }

        let faceGeometry = ARSCNFaceGeometry(device: device)
        let faceNode = SCNNode(geometry: faceGeometry)
        faceNode.geometry?.firstMaterial?.fillMode = .lines
        faceNode.geometry?.firstMaterial?.transparency = 0

        glassesPlane.firstMaterial?.isDoubleSided = true
        updateGlasses(with: 0)
        setupNodes(node: glassesNode, faceNode: faceNode, isBen: false, geometry: glassesPlane)

        benPlane.firstMaterial?.isDoubleSided = true
        updateBen()
        setupNodes(node: benNode, faceNode: faceNode, isBen: true, geometry: benPlane)

        return faceNode
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor,
              let faceGeometry = node.geometry as? ARSCNFaceGeometry,
              let pixelBuffer = self.sceneView.session.currentFrame?.capturedImage
        else { return }

        faceGeometry.update(from: faceAnchor.geometry)

        try? VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .right,
            options: [:]).perform([VNCoreMLRequest(model: model) { [weak self] request, error in

                guard let firstResult = (request.results as? [VNClassificationObservation])?.first else { return }

                DispatchQueue.main.async {
                    if firstResult.confidence > 0.90 {
                        print(firstResult.identifier)
                        switch firstResult.identifier {
                        case "Neutral":
                            self?.changeNodes(ben: false, glasses: true)
                            self?.updateGlasses(with: 0)
                        case "Happiness":
                            self?.changeNodes(ben: true, glasses: false)
                        case "Surprise":
                            self?.changeNodes(ben: false, glasses: true)
                            self?.updateGlasses(with: 2)
                        default:
                            return
                        }
                    }
                }

            }])
    }

    func changeNodes(ben: Bool, glasses: Bool) {
        if ben {
            self.benNode.isHidden = false
            self.glassesNode.isHidden = true
            self.player?.play()
        } else if glasses {
            self.benNode.isHidden = true
            self.glassesNode.isHidden = false
            if let player = self.player, player.isPlaying {
                player.pause()
            }
        }
    }

    func setupNodes(node: SCNNode, faceNode: SCNNode, isBen: Bool, geometry: SCNPlane) {
        node.position.z = faceNode.boundingBox.max.z * 3 / 4
        node.position.y = isBen ? 0.053 : 0.022
        node.geometry = geometry
        faceNode.addChildNode(node)
    }
}
