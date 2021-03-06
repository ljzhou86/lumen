!
!        Copyright (C) 2000-2016 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): MG, CA, DS
! 
! This file is distributed under the terms of the GNU 
! General Public License. You can redistribute it and/or 
! modify it under the terms of the GNU General Public 
! License as published by the Free Software Foundation; 
! either version 2, or (at your option) any later version.
!
! This program is distributed in the hope that it will 
! be useful, but WITHOUT ANY WARRANTY; without even the 
! implied warranty of MERCHANTABILITY or FITNESS FOR A 
! PARTICULAR PURPOSE.  See the GNU General Public License 
! for more details.
!
! You should have received a copy of the GNU General Public 
! License along with this program; if not, write to the Free 
! Software Foundation, Inc., 59 Temple Place - Suite 330,Boston, 
! MA 02111-1307, USA or visit http://www.gnu.org/copyleft/gpl.txt.
!
subroutine WF_symm_kpoint(b_to_load,ikbz,Xk,WF_k_out)
 !
 use pars,          ONLY:SP,cZERO
 use electrons,     ONLY:n_spin,n_spinor
 use wave_func,     ONLY:WF,wf_ng
 use R_lattice,     ONLY:bz_samp,g_rot
 use D_lattice,     ONLY:idt_index,spin_sop,i_time_rev,nsym
 !
 implicit none
 !
 integer,       intent(in)  :: ikbz,b_to_load(2)
 type(bz_samp), intent(in)  :: Xk
 complex(SP),   intent(out) :: WF_k_out(wf_ng,b_to_load(1):b_to_load(2),n_spin)
 !
 ! Work space
 !
 integer :: ik,is,i_spin,ib,iwf,ig
 !
 ik = Xk%sstar(ikbz,1)
 is = Xk%sstar(ikbz,2)
 !
 WF_k_out=cZERO
 !
 if(is==idt_index) then
   !  
   do ib=b_to_load(1),b_to_load(2)
     do i_spin=1,n_spin
       iwf=WF%index(ib,ik,i_spin)
       WF_k_out(:,ib,i_spin)=WF%c(:,iwf)
     enddo
   enddo
   !
 else
   !
   WF_k_out=cZERO
   !
   do ib=b_to_load(1),b_to_load(2)
     do i_spin=1,n_spin
       iwf=WF%index(ib,ik,i_spin)
       WF_k_out(g_rot(is,:wf_ng),ib,i_spin)=WF%c(:wf_ng,iwf)
     enddo
     !
     if(n_spinor==2) &
&      forall(ig=1:wf_ng) WF_k_out(ig,ib,:)=matmul(spin_sop(:,:,is),WF_k_out(ig,ib,:))
     !
   enddo
   !
   if(is>nsym/(1+i_time_rev)) WF_k_out=conjg(WF_k_out)
   !
 endif
 !
end subroutine WF_symm_kpoint
