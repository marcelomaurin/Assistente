"""Regression checks for authored Tripo weights and relaxed-pose clothing."""
from pathlib import Path
import sys
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from tripo_rig_import import align_vector,bone_map,clean_component_weights

def main():
 for a,b in [([1,0,0],[0,1,0]),([0,1,0],[0,-1,0]),([0,0,1],[0,0,1])]:
  r=align_vector(a,b)
  assert np.allclose(r@np.asarray(a),b,atol=1e-8)
  assert np.allclose(r.T@r,np.eye(3),atol=1e-8) and abs(np.linalg.det(r)-1)<1e-8
 assert bone_map('L_Thumb3')=='finger1-3.L'
 assert bone_map('R_Pinky1')=='finger5-1.R'
 assert bone_map('L_Hand')=='wrist.L'
 try:bone_map('UnknownBone')
 except ValueError:pass
 else:raise AssertionError('Unknown bone silently accepted')
 points=np.array([[-.1,.1,0],[-.1,.2,0],[-.1,.3,0],[-.1,.35,0],[.1,.6,0]])
 weights=np.array([[0,1,0],[0,1,0],[.2,0,.8],[0,1,0],[1,0,0]],float)
 names=['Hip','L_Thigh','L_Hand']
 fixed,info=clean_component_weights(points,weights,names,{'Hip':np.array([0,.55,0]),'Head':np.array([0,.88,0])},1)
 assert info['category']=='lower-body' and info['repaired_vertices']==1
 assert np.allclose(fixed.sum(1),1) and np.all(fixed>=0)
 assert np.all(fixed[:,2]==0),'Pants are still attached to the hand'
 assert np.allclose(fixed[[0,1,3,4]],weights[[0,1,3,4]]),'Valid weights changed'
 print('PASS: rig rotation bases, left/right finger controls, unknown-bone rejection, pants/hand decoupling, normalization and unchanged valid weights')
if __name__=='__main__':main()
