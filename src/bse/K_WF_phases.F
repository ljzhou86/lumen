!
!        Copyright (C) 2000-2016 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): AM
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
subroutine K_WF_phases(Xk)
 !
 ! This routine evaluates the WF phases needed to evaluate the correlation
 ! collisions
 !
 !  <n k1_bz |exp iG.r|m k2_bz> = <n k1_ibz s1 |exp iG.r|m k2_ibz s2>  =
 !                                <n k1_ibz |exp iG.r|m k2_ibz s1^{-1} x s2 > 
 !
 ! now, in general, s1^{-1} x s2 is not a symmetry in the star of k2_ibz, so we
 ! define and use the table Xk%s_table:
 !
 ! is_in_the_star_of_k2=Xk%s_table(k2,s1^{-1} x s2 )
 !
 ! to get
 !
 !  <n k1_bz |exp iG.r|m k2_bz> =  <n k1_ibz |exp iG.r|m k2_ibz  is_in_the_star_of_k2>*PHASE
 !
 ! where |k2 ib s1^{-1} x s2 > = PHASE * |k2 ib is_in_the_star_of_k2>
 !
 use pars,          ONLY:SP,cZERO
 use memory_m,      ONLY:mem_est
 use FFT_m,         ONLY:fft_size
 use D_lattice,     ONLY:nsym
 use R_lattice,     ONLY:bz_samp
 use BS,            ONLY:WF_phase,BS_res_K_corr,BS_bands
 use com,           ONLY:msg
 use parallel_m,    ONLY:PP_redux_wait,PAR_IND_WF_linear
 use electrons,     ONLY:n_sp_pol,n_spinor
 !
 implicit none
 !
 ! Work Space
 !
 type(bz_samp) :: Xk
 !
 complex(SP) :: wf_cmp,WF_symm1(fft_size,n_spinor),WF_symm2(fft_size,n_spinor)
 integer     :: i_k,i_s,i_s_star,i_b,i_sp,n_phases(1)
 !
 if (.not.BS_res_K_corr) return 
 !
 call section('=','Wave-Function Phases')
 !
 if (.not.allocated(WF_phase)) then
   allocate(WF_phase(Xk%nibz,nsym,BS_bands(1):BS_bands(2),n_sp_pol))
   call mem_est("WF_phase",(/size(WF_phase)/),(/2*SP/))
 endif
 WF_phase=cZERO
 !
 n_phases=0
 !
 do i_k=1,Xk%nibz
   !
   do i_s=1,nsym
     !
     i_s_star=Xk%s_table(i_k,i_s)
     !
     if (i_s==i_s_star) then
       !
       do i_b=BS_bands(1),BS_bands(2)
         !
         if (.not.PAR_IND_WF_linear%element_2D(i_b,i_k)) cycle
         !
         n_phases=n_phases+1
         WF_phase(i_k,i_s,i_b,:)=1._SP
         !
       enddo
       !
     else
       !
       do i_sp=1,n_sp_pol
         !
         do i_b=BS_bands(1),BS_bands(2)
           !
           if (.not.PAR_IND_WF_linear%element_2D(i_b,i_k)) cycle
           !
           if (WF_phase(i_k,i_s,i_b,i_sp)/=cZERO) cycle
           !
           call WF_apply_symm((/i_b,i_k,i_s      ,i_sp/),WF_symm1)
           call WF_apply_symm((/i_b,i_k,i_s_star ,i_sp/),WF_symm2)
           !
           wf_cmp=dot_product(WF_symm1(:,1),WF_symm2(:,1))
           if(n_spinor>1) wf_cmp=wf_cmp+dot_product(WF_symm1(:,2),WF_symm2(:,2))
           !
           if (abs(abs(wf_cmp)-1._SP)<=1.E-3_SP) then
             n_phases=n_phases+1
             WF_phase(i_k,i_s,i_b,i_sp)=conjg(wf_cmp)
           else
             WF_phase(i_k,i_s,i_b,i_sp)=-99._SP
           endif
         enddo
       enddo
       !
     endif
   enddo
 enddo
 !
 call PP_redux_wait(WF_phase)
 call PP_redux_wait(n_phases)
 !
 call msg('r','[BSE] WF phases found  [o/o]:',real(n_phases(1),SP)/real(size(WF_phase),SP)*100._SP)
 !
end subroutine K_WF_phases
