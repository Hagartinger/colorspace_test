/**
 * Copyright (c) 2016 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import MetalKit
import QuartzCore
import simd

protocol MetalViewControllerDelegate : class {
  func updateLogic(_ timeSinceLastUpdate:CFTimeInterval)
  func renderObjects(_ drawable:CAMetalDrawable)
}

class MetalViewController: UIViewController {

  var device: MTLDevice! = nil
  var commandQueue: MTLCommandQueue! = nil
  var textureLoader: MTKTextureLoader! = nil
  var fillRedCompute:MTLComputePipelineState! = nil
  var outputTexture:MTLTexture! = nil
    
  @IBOutlet weak var mtkView: MTKView! {
    didSet {
      mtkView.delegate = self
      mtkView.preferredFramesPerSecond = 60
      mtkView.framebufferOnly = false
    }
  }
  
  weak var metalViewControllerDelegate:MetalViewControllerDelegate?
  
  override func viewDidLoad() {
    super.viewDidLoad()
      
    let colorSpace =  CGColorSpaceCreateDeviceRGB()
    let model = colorSpace.model
      let name = colorSpace.name! as NSString
    device = MTLCreateSystemDefaultDevice()
    textureLoader = MTKTextureLoader(device: device)
    mtkView.device = device
    commandQueue = device.makeCommandQueue()
    var shadersLibrary = device.makeDefaultLibrary()!
    guard var fill_red_func = shadersLibrary.makeFunction(name: "fill_red") else { return }
      do{
          fillRedCompute = try device.makeComputePipelineState(function: fill_red_func)
          
          let p3_png = Bundle.main.url(forResource: "p3", withExtension: "png")!
          
          outputTexture = try textureLoader.newTexture(URL: p3_png)
      } catch {}
    
  }
    
  func render(_ drawable: CAMetalDrawable?) {
    guard let drawable = drawable else { return }
      let drawable_texture = drawable.texture
      let commandBuffer = commandQueue.makeCommandBuffer()
      
      ///* Fill drawable with red color
      let encoder = commandBuffer?.makeComputeCommandEncoder()
      encoder?.setComputePipelineState(fillRedCompute)
      
      encoder?.setTexture(drawable_texture, index: 0)
      let width = fillRedCompute.threadExecutionWidth;
      let height = fillRedCompute.maxTotalThreadsPerThreadgroup / width;
      let groupSize = MTLSize(width: width, height: height, depth: 1)
      let numberOfGroups = MTLSize(width: drawable_texture.width / width, height: drawable_texture.height / height, depth: 1)
      encoder?.dispatchThreadgroups(numberOfGroups, threadsPerThreadgroup: groupSize)
      encoder?.endEncoding()
      //*/
      
      ///* Copy p3.png into drawable
      
      let blitEncoder = commandBuffer?.makeBlitCommandEncoder()
      blitEncoder?.copy(from: outputTexture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: outputTexture.width, height: outputTexture.height, depth: 1), to: drawable_texture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
      blitEncoder?.endEncoding()
      
      //*/
      commandBuffer?.present(drawable)
      commandBuffer?.commit()
    self.metalViewControllerDelegate?.renderObjects(drawable)
  }

}

// MARK: - MTKViewDelegate
extension MetalViewController: MTKViewDelegate {
  
  // 1
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
  }
  
  // 2
  func draw(in view: MTKView) {
    render(view.currentDrawable)
  }
  
}

