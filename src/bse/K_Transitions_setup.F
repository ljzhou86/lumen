!
!        Copyright (C) 2000-2016 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): AM, DS
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
subroutine K_Transitions_setup(iq,Ken,Xk,FILL_the_groups)
 !
 ! Out: 
 !
 !   BS_K_dim
 !   BS_H_dim
 !   BS_nT_at_k
 !
 ! Filling (FILL_the_groups=.TRUE.) of Transition groups
 !
 !type BS_T_group
 !  integer                       :: ik         ! ik index (\in IBZ)
 !  integer                       :: first_cv   ! Position in the cv transitions @ k
 !  integer                       :: size       
 !  complex(SP), allocatable      :: table(:,:) ! (/ikbz,iv,ic,i_sp/)
 !  complex(SP), allocatable      :: Z(size)
 !  real(SP)   , allocatable      :: E(size)
 !  real(SP)   , allocatable      :: f(size)
 !  real(SP)   , allocatable      :: W(size)
 !end type BS_T_group
 !
 use pars,         ONLY:SP,IP
 use memory_m,     ONLY:mem_est
 use com,          ONLY:warning,error
 use BS_solvers,   ONLY:BSS_add_antiresonant,BSS_mode
 use BS,           ONLY:BS_K_dim,BS_H_dim,T_group,BS_eh_en,BS_K_coupling,&
&                       BS_bands,BS_nT_at_k,BSE_mode,BS_T_grp,BS_nT_grps,&
&                       BS_not_const_eh_f,BS_Blocks_and_Transitions_alloc
 use X_m,          ONLY:global_gauge,Dipole_Energy_treshold
 use parallel_m,   ONLY:PAR_IND_WF_b_and_k,PAR_IND_T_all,PAR_IND_T_ordered,PAR_IND_T_groups,&
&                       PAR_IND_T_Haydock
 use electrons,    ONLY:levels,n_sp_pol,spin_occ,filled_tresh,E_SOC_nbands,E_SOC_table
 use com,          ONLY:msg
 use R_lattice,    ONLY:qindx_X,bz_samp
 !
 implicit none
 !
 type(levels) :: Ken
 type(bz_samp):: Xk
 integer      :: iq
 logical      :: FILL_the_groups,l_trans_in_group,l_grp_to_grp
 !
 ! Work Space
 !
 integer :: ikbz,iv,ic,iv_SOC(2/n_sp_pol),ic_SOC(2/n_sp_pol),ik,ikp,i_sp,i_star,nb(2),&
&           i_T_group_now,i_T_group_last,i_g,n_loops,i_loop,i_T_in_the_grp,pert_range(2/n_sp_pol,2)
 real(SP):: E_eh,Eo_eh,E_eh_SOC_corr(2/n_sp_pol),E_v_SOC(2/n_sp_pol),E_c_SOC(2/n_sp_pol),f_eh,f_eh_RES,f_eh_REF,f_e,f_h
 integer, allocatable :: i_T_at_k(:)
 !
 if (FILL_the_groups) then
   !
   call section('+','Transition Groups build-up')
   !
   allocate(BS_T_grp(BS_nT_grps))
   do i_g=1,BS_nT_grps
     BS_T_grp(i_g)%size=0
   enddo
   n_loops=2
   if (any(BS_nT_at_k==0)) call warning(' Null BSE kernel block dimension(s) found.')
   !
   allocate(PAR_IND_WF_b_and_k%element_2D(BS_bands(2),Xk%nibz))
   PAR_IND_WF_b_and_k%element_2D=.FALSE.
   !
   if (index(BSS_mode,'h')/=0) then
     allocate(PAR_IND_T_Haydock%element_1D(BS_nT_grps))
     PAR_IND_T_Haydock%element_1D=.FALSE.
   endif
   !
 else
   !
   allocate(BS_nT_at_k(Xk%nibz))
   call mem_est("BS_nT_at_k",(/Xk%nibz/),(/IP/))
   BS_nT_at_k=0
   n_loops=1
   !
 endif 
 !
 allocate(i_T_at_k(Xk%nibz))
 !
 call k_build_up_BZ_tables(Xk)
 !
 nb(1)=Ken%nbf+1
 nb(2)=Ken%nbm
 !
 do i_loop=1,n_loops
   !
   if (i_loop==2) call BS_Blocks_and_Transitions_alloc(Ken,0)
   !
   i_T_at_k=0
   BS_K_dim=0
   i_T_group_now=0
   i_T_group_last=0
   !
   do ik=1,Xk%nibz
     !
     do iv=BS_bands(1),nb(2)
       do ic=nb(1),BS_bands(2)
         !
         do i_star=1,Xk%nstar(ik)
           !
           ikbz=Xk%k_table(ik,Xk%star(ik,i_star))
           ikp =Xk%sstar(qindx_X(iq,ikbz,1),1)
           !
           do i_sp=1,n_sp_pol
             !
             if (.not.T_is_ok()) cycle
             !
             BS_K_dim=BS_K_dim+1
             i_T_at_k(ik)=i_T_at_k(ik)+1
             !
             if (.not. FILL_the_groups) then
               BS_nT_at_k(ik)=BS_nT_at_k(ik)+1
               cycle
             endif
             !
             i_T_group_now=T_group(BS_K_dim)
             !
             if (i_loop==1) BS_T_grp(i_T_group_now)%size=BS_T_grp(i_T_group_now)%size+1
             !
             l_trans_in_group=PAR_IND_T_groups%element_1D(i_T_group_now)
             !
             l_grp_to_grp= any( PAR_IND_T_ordered%element_2D(i_T_group_now,:)) .or. &
&                          any( PAR_IND_T_ordered%element_2D(:,i_T_group_now))
             !
             if (BS_k_coupling) l_grp_to_grp=l_grp_to_grp .or. any( PAR_IND_T_all%element_2D(i_T_group_now,:) ) &
&                                                         .or. any( PAR_IND_T_all%element_2D(:,i_T_group_now))
             !
             if ( .not. (l_trans_in_group .or. l_grp_to_grp) ) cycle
             !
             if (i_T_group_now/=i_T_group_last) then
               !
               i_T_group_last=i_T_group_now
               i_T_in_the_grp=0
               !
               if (i_loop==2) then
                 !
                 call BS_Blocks_and_Transitions_alloc(Ken,i_T_group_now)
                 !
                 BS_T_grp(i_T_group_now)%ik      =ik
                 BS_T_grp(i_T_group_now)%first_cv=BS_K_dim
                 !
               endif
               !
             endif
             !
             if (i_loop==1) cycle
             !
             i_T_in_the_grp=i_T_in_the_grp+1
             !
             BS_T_grp(i_T_group_now)%table(i_T_in_the_grp,:)=(/ikbz,iv,ic,i_sp/)
             !
             PAR_IND_WF_b_and_k%element_2D(ic,ik )=.TRUE.
             PAR_IND_WF_b_and_k%element_2D(iv,ikp)=.TRUE.
             !
             if (index(BSS_mode,'h')/=0) PAR_IND_T_Haydock%element_1D(i_T_group_now)=.TRUE.
             !
             BS_T_grp(i_T_group_now)%E(i_T_in_the_grp) =E_eh
             BS_T_grp(i_T_group_now)%f(i_T_in_the_grp) =f_eh
             BS_T_grp(i_T_group_now)%f_RES(i_T_in_the_grp)=f_eh_RES
             !
             if (associated(Ken%Z)) BS_T_grp(i_T_group_now)%Z(i_T_in_the_grp)=Ken%Z(ic,ik,i_sp)*Ken%Z(iv,ikp,i_sp)
             !
             ! Note that W is negative as the linewidth is negative(positive) above(below) the Fermi level.
             ! Presently there is the abs value here and a minus in K_IP.F
             !
             if (associated(Ken%W)) BS_T_grp(i_T_group_now)%W(i_T_in_the_grp)=abs(Ken%W(ic,ik,i_sp))+abs(Ken%W(iv,ikp,i_sp))
             !
             !
           enddo ! spin
         enddo ! symmetries
       enddo ! k (ibz)
       !
     enddo ! conduction
   enddo ! valence
   !
 enddo ! loop
 !
 BS_H_dim=BS_K_dim
 if (BS_K_coupling) BS_H_dim=2*BS_K_dim
 !
 if (.not.FILL_the_groups) then
   !
   if (any(BS_nT_at_k==0)) call warning(' Null BSE kernel block dimension(s) found.')
   if (sum(BS_nT_at_k)==0) call   error(' The whole BSE hase zero dimension !')
   !
   if (.not.BSS_add_antiresonant.and.BS_not_const_eh_f.and..not.BS_K_coupling) then
     call warning('Fractional e/h occupations. Retarded BSEmode forced.')
     BSE_mode='retarded'
     BSS_add_antiresonant=.true.
   endif
   !
 endif
 !
 ! REPORT
 !
 if (FILL_the_groups) call msg('r','[BSK] Transition groups (total)',BS_nT_grps)
 !
 ! CLEAN UP
 !
 deallocate(i_T_at_k)
 !
 contains
   !
   logical function T_is_ok( )
     !
     T_is_ok=.TRUE.
     !
     E_eh= Ken%E(ic,ik ,i_sp)-Ken%E(iv,ikp,i_sp)
     if(     associated(Ken%Eo)) Eo_eh= Ken%Eo(ic,ik ,i_sp)-Ken%Eo(iv,ikp,i_sp)
     if(.not.associated(Ken%Eo)) Eo_eh= E_eh
     !
     ! Small energy transitions. Dipoles in length gauge are not defined
     if ( abs(Eo_eh) < Dipole_Energy_treshold .and. trim(global_gauge)=="length" ) T_is_ok=.FALSE.
     !
     !
     ! Occupations Factors
     !=====================
     !
     f_eh_REF =(Ken%f(iv,ikp,i_sp)-Ken%f(ic,ik ,i_sp))/spin_occ
     f_eh     =f_eh_REF
     f_eh_RES =f_eh_REF
     !
     ! f_eh  enter the excitonic Hamiltonian
     ! f_eh_RES enter the residual of the dielectric constant
     !
     !
     f_e = (         Ken%f(iv,ikp,i_sp))/spin_occ
     f_h = (spin_occ-Ken%f(ic,ik ,i_sp))/spin_occ
     !
     !
     ! A 0.001 % fractional occupation swiches on the particular treatment of finite temp. BSE 
     if ( abs(abs(f_eh_REF)-1._SP)> filled_tresh ) BS_not_const_eh_f=.TRUE.
     !
     ! f_eh<0 transitions are included in the anti-resonant part
     ! f_eh=0 transitions give no contribution to absorption and are not considered
     if ( f_eh_REF<=0._SP ) T_is_ok=.FALSE.
     !
     !
       !
       ! If I've included in valence states that are almost empty
       ! or in conduction states that are almost full, those are neglected
       if ( (f_e<=filled_tresh) .or. (f_h<=filled_tresh) ) T_is_ok=.FALSE.
       !
     !
     if (any((/abs(E_eh)<BS_eh_en(1).and.BS_eh_en(1)>0._SP,&
&              abs(E_eh)>BS_eh_en(2).and.BS_eh_en(2)>0._SP/))) T_is_ok=.FALSE.
     !
   end function
   !
end subroutine
