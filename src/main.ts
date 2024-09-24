import {vec3} from 'gl-matrix';
const Stats = require('stats-js');
import * as DAT from 'dat.gui';
import Icosphere from './geometry/Icosphere';
import Square from './geometry/Square';
import Cube from './geometry/Cube';
import OpenGLRenderer from './rendering/gl/OpenGLRenderer';
import Camera from './Camera';
import {setGL} from './globals';
import ShaderProgram, {Shader} from './rendering/gl/ShaderProgram';

// Define an object with application parameters and button callbacks
// This will be referred to by dat.GUI's functions that add GUI elements.
const controls = {
  tesselations: 5,
  color: [255, 0, 0],
  innerColor: [225, 150, 85],
  outerColor: [22, 36, 45],
  backgroundColor: [9, 27, 27],
  fireFreq: 0.8,
  speed: 1.0,
  detail: 1.0,
  voronoiScale: 1.0,
  'Load Scene': loadScene, // A function pointer, essentially
  'Reset Scene': resetScene,
  'Ghost Fire': GhostFire,
  'Cherry': CherryFire,
  'Evening': EveningFire,
};

let icosphere: Icosphere;
let square: Square;
let cube: Cube;
let prevTesselations: number = 5;
let time : number = 0;

function loadScene() {
  icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, controls.tesselations);
  icosphere.create();
  square = new Square(vec3.fromValues(0, 0, 0));
  square.create();
  cube = new Cube(vec3.fromValues(0, 0, 0));
  cube.create();
}

function resetScene()
{
  controls.tesselations = 5;
  controls.fireFreq = 0.8;
  controls.speed = 1.0;
  controls.detail = 1.0;
  controls.voronoiScale = 1.0;
  EveningFire();
  time = 0;
}

function GhostFire()
{
  controls.innerColor = [30, 115, 180];
  controls.outerColor = [155, 255, 240];
  controls.backgroundColor = [4,27,36];
}

function CherryFire()
{
  controls.innerColor = [255, 95, 95];
  controls.outerColor = [240, 160, 123];
  controls.backgroundColor = [250, 160, 160];
}

function EveningFire()
{
  controls.innerColor = [225, 150, 85];
  controls.outerColor = [22, 36, 45];
  controls.backgroundColor = [9, 27, 27];
}

function main() {
  // Initial display for framerate
  const stats = Stats();
  stats.setMode(0);
  stats.domElement.style.position = 'absolute';
  stats.domElement.style.left = '0px';
  stats.domElement.style.top = '0px';
  document.body.appendChild(stats.domElement);

  // Add controls to the gui
  const gui = new DAT.GUI();
  gui.add(controls, 'tesselations', 0, 8).step(1).listen();
  gui.add(controls, 'fireFreq', 0, 2).step(0.1).listen();
  gui.add(controls, 'speed', 0, 5).step(0.2).listen();
  gui.add(controls, 'detail', 0, 5).step(0.1).listen();
  gui.add(controls, 'voronoiScale', 0, 5).step(0.1).listen();
  gui.add(controls, 'Load Scene');
  gui.add(controls, 'Reset Scene');
  gui.add(controls, 'Ghost Fire');
  gui.add(controls, 'Cherry');
  gui.add(controls, 'Evening');
  // gui.addColor(controls, 'color');
  gui.addColor(controls, 'innerColor').listen();
  gui.addColor(controls, 'outerColor').listen();
  gui.addColor(controls, 'backgroundColor').listen();

  // get canvas and webgl context
  const canvas = <HTMLCanvasElement> document.getElementById('canvas');
  const gl = <WebGL2RenderingContext> canvas.getContext('webgl2');
  if (!gl) {
    alert('WebGL 2 not supported!');
  }
  // `setGL` is a function imported above which sets the value of `gl` in the `globals.ts` module.
  // Later, we can import `gl` from `globals.ts` to access it
  setGL(gl);

  // Initial call to load scene
  loadScene();

  const camera = new Camera(vec3.fromValues(0, 0, 5), vec3.fromValues(0, 0, 0));

  const renderer = new OpenGLRenderer(canvas);
  renderer.setClearColor(0.2, 0.2, 0.2, 1);
  gl.enable(gl.DEPTH_TEST);
  gl.enable(gl.BLEND);
  gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

  const lambert = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/lambert.vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/lambert.frag.glsl')),
  ]);

  // This function will be called every frame
  function tick() {
    ++time;
    camera.update();
    stats.begin();
    gl.viewport(0, 0, window.innerWidth, window.innerHeight);
    renderer.clear();
    if(controls.tesselations != prevTesselations)
    {
      prevTesselations = controls.tesselations;
      icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, prevTesselations);
      icosphere.create();
    }

    const colorCtl = new Float32Array([
      controls.color[0] / 255.0,
      controls.color[1] / 255.0,
      controls.color[2] / 255.0,
      1.0
  ]);

  const inCol = new Float32Array([
    controls.innerColor[0] / 255.0,
    controls.innerColor[1] / 255.0,
    controls.innerColor[2] / 255.0,
    1.0
]);

const outCol = new Float32Array([
  controls.outerColor[0] / 255.0,
  controls.outerColor[1] / 255.0,
  controls.outerColor[2] / 255.0,
  1.0
]);

const bgCol = new Float32Array([
  controls.backgroundColor[0] / 255.0,
  controls.backgroundColor[1] / 255.0,
  controls.backgroundColor[2] / 255.0,
  1.0
]);

renderer.setClearColor(bgCol[0], bgCol[1], bgCol[2], bgCol[3]);


    lambert.setTime(time);
    lambert.setFloat('u_Freq', controls.fireFreq);
    lambert.setFloat('u_Speed', controls.speed);
    lambert.setFloat('u_Detail', controls.detail);
    lambert.setFloat('u_VoronoiScale', controls.voronoiScale);
    lambert.setVec4('u_InnerCol', inCol);
    lambert.setVec4('u_OuterCol', outCol);

    renderer.render(camera, lambert, [
      icosphere,
      //cube,
      // square,
    ], colorCtl);
    stats.end();

    // Tell the browser to call `tick` again whenever it renders a new frame
    requestAnimationFrame(tick);
  }

  window.addEventListener('resize', function() {
    renderer.setSize(window.innerWidth, window.innerHeight);
    camera.setAspectRatio(window.innerWidth / window.innerHeight);
    camera.updateProjectionMatrix();
  }, false);

  renderer.setSize(window.innerWidth, window.innerHeight);
  camera.setAspectRatio(window.innerWidth / window.innerHeight);
  camera.updateProjectionMatrix();

  // Start the render loop
  tick();
}

main();
