!
!        Copyright (C) 2000-2017 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): AM MG DS
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
subroutine K_Haydock(iq,W)
 !
 use pars,           ONLY:SP,schlen,cI,cZERO,cONE
 use com,            ONLY:error
 use functions,      ONLY:NAN
 use wrapper_omp,    ONLY:V_by_V_plus_V_omp
 use X_m,            ONLY:Epsilon_ii,Epsilon_ij,X_drude_term,iw_ref,global_gauge
 use R_lattice,      ONLY:q_norm
 use frequency,      ONLY:w_samp
 use com,            ONLY:msg,isec
 use BS_solvers,     ONLY:BSS_n_descs,Haydock_treshold,BSS_description,io_BSS_Haydock,Co_factor,&
&                         Haydock_vector,BS_HAYVEC_alloc,BS_HAYVEC_free,Haydock_terminator,Haydock_v0_mod
 use BS,             ONLY:BS_K_Coupling,BSE_mode,BS_Blocks_symmetrize_K,BS_T_grp,BS_nT_grps
 use LIVE_t,         ONLY:LIVE_message
 use stderr,         ONLY:tty_size,intc,real2ch
 use IO_m,           ONLY:io_control,OP_RD_CL,OP_WR_CL,VERIFY,REP
 use parser_m,       ONLY:parser
 use parallel_m,     ONLY:PAR_IND_T_groups,PP_bcast,PAR_IND_T_Haydock,PAR_COM_T_Haydock
 !
 !
#if defined _TIMING
 use timing_m,       ONLY:timing
#endif
 !
 implicit none
 !
 type(w_samp)  ::W
 integer       ::iq
 !
 ! Work Space
 !
 integer            ::it,it_on_disk,i_g
 integer, parameter ::Max_iterations=1000
 type(Haydock_vector),allocatable :: Vn(:),Vnm1(:),Vnp1(:),V0(:)
 complex(SP),allocatable :: Cf(:)
 !
 !
 real(SP)           ::reached_treshold
 real(SP)           ::Bf(Max_iterations),Af(Max_iterations)
 integer            ::ItParity
 complex(SP)        ::v0_mod_
 character(schlen)  ::dumb_ch
 logical            ::use_cpl_scheme
 logical, external  ::stop_now
 !
 ! I/O
 !
 !integer           :: ID,io_err
 !
 call PARALLEL_Haydock_VEC_COMMs('assign')
 !
#if defined _TIMING
 call timing('Haydock Solver',OPR='start')
#endif
 !
 if (isec(2)/=0) then
   call section('=','Haydock solver')
 else if (isec(2)==0) then
   call section('+','Haydock solver')
 endif
 !
 call BS_Blocks_symmetrize_K()
 !
 ! Use terminator?
 if (.not.Haydock_terminator) call parser('BSHayTer',Haydock_terminator)
 !
 ! Which approach
 use_cpl_scheme=BS_K_Coupling !.or.allocated(BS_T_grp(1)%Z)
 !
 !
 !
 ! Allocate Haydock vectors:
 !
 allocate(V0(BS_nT_grps))
 call BS_HAYVEC_alloc(V0)
 !
 !
 !
 if (use_cpl_scheme) then
   allocate(Cf(Max_iterations+1))
   !
   !
 end if
 !
 allocate(Vn(BS_nT_grps),Vnp1(BS_nT_grps),Vnm1(BS_nT_grps))
 call BS_HAYVEC_alloc(Vn)
 call BS_HAYVEC_alloc(Vnm1)
 call BS_HAYVEC_alloc(Vnp1)
 !
 !
 ! Haydock Coefficients and restart vector on disk
 !=================================================
 it_on_disk=0
 ! call io_control(ACTION=OP_RD_CL,COM=REP,MODE=VERIFY,SEC=(/1/),ID=ID)
 ! !
 ! if (use_cpl_scheme) then 
 !  !
 !
 !
 !   io_err=io_BSS_Haydock(ID,1,BS_K_dim,reached_treshold,Af(1),Bf(:2)&
 !        &,Vmm1,Vm,Vnp1=Vmp1,Cf=Cf(:2))   
 !
 !
 ! else
 !   io_err=io_BSS_Haydock(ID,1,BS_K_dim,reached_treshold,Af(1),Bf(:2),Vmm1,Vm)
 !endif
 !
 !
 ! if (io_err>0) call error('K_Haydock: restart of Haydock temporary disabled') 
 !
 ! if (io_err>0) then 
 !   !
 !   it_on_disk=io_err 
 !   call io_control(ACTION=OP_RD_CL,SEC=(/1,2/),ID=ID)
 !   if (use_cpl_scheme) then 
 !
 !
 !      io_err=ioBSS_Haydock(ID,it_on_disk,BS_K_dim,reached_treshold,Af(:it_on_disk),&
 !      &                   Bf(:it_on_disk+1),Vnm1,Vn,Vnp1=Vnp1,Cf=Cf(:it_on_disk+1))
 !
 !
 !   else
 !     io_err=io_BSS_Haydock(ID,it_on_disk,BS_K_dim,reached_treshold,Af(:it_on_disk),&
 !     &      Bf(:it_on_disk+1),Vmm1,Vm)
 !     call msg('s','[Haydock] Restart DB with accuracy ',reached_treshold)
 !   end if
 !   !
 ! endif
 !
 ! Update Descriptions
 !=====================
 BSS_n_descs=BSS_n_descs+2
 BSS_description(BSS_n_descs-1)=' '
 BSS_description(BSS_n_descs)=' Haydock|Accuracy (requested) [o/o]:'&
      &// trim(real2ch(Haydock_treshold))
 BSS_n_descs=BSS_n_descs+1
 BSS_description(BSS_n_descs)='        |Accuracy (reached)   [o/o]:'&
      &// trim(real2ch(0._SP))
 BSS_n_descs=BSS_n_descs+1
 BSS_description(BSS_n_descs)='        |Iteration            [o/o]: 0'
 !
 call msg('r','Accuracy (requested) [o/o]:',Haydock_treshold)
 !
 ! Initialization of Haydock vectors and tridiagonal matrix elements
 !
 if (it_on_disk==0) then
   !
   do i_g=1,BS_nT_grps
     !
     if (.not.PAR_IND_T_Haydock%element_1D(i_g)) cycle
     !
     Vn(i_g)%fragment  = cZERO
     Vnm1(i_g)%fragment= cZERO
     Vnp1(i_g)%fragment= cZERO
     !
     V0(i_g)%fragment  = cZERO
     !
     !
   enddo
   !
   Af= 0._SP
   Bf= 0._SP
   !
 end if
 !
 do i_g=1,BS_nT_grps
   if (.not.PAR_IND_T_groups%element_1D(i_g)) cycle
   V0(i_g)%fragment(:) =BS_T_grp(i_g)%dipoles_R(:)*sqrt(BS_T_grp(i_g)%f_RES(:))
   !
   !
 enddo
 !
 do i_g = 1,BS_nT_grps
   if (.not.PAR_IND_T_Haydock%element_1D(i_g)) cycle
#if defined _MPI
   call PP_bcast(V0(i_g)%fragment(:),0,COMM=PAR_COM_T_Haydock(i_g)%COMM)
#endif    
   !
   !
 end do
 !
 if (use_cpl_scheme) then ! [***] Initialization non Hermitian case
   !
   ! Before starting iterate one needs
   !
   ! | Vm > =     |q->0>/(<q->0| F (H |q->0>))
   ! | Vmp1 > = H |Vm>
   !
   ItParity = (-1)**it_on_disk
   if (it_on_disk==0) then
      Cf= cZERO
      !
      !
      call K_multiply_by_V(V0,Vnp1,ItParity)
      call K_dot_product(v0_mod_,V0,Vnp1)
      Haydock_v0_mod=sqrt(2._SP*real(v0_mod_))
      Cf(1) = cZERO
      !
      !
      do i_g=1,BS_nT_grps
        if (.not.PAR_IND_T_Haydock%element_1D(i_g)) cycle
        !
        Vn(i_g)%fragment   = V0(i_g)%fragment/Haydock_v0_mod
        Vnp1(i_g)%fragment = Vnp1(i_g)%fragment/Haydock_v0_mod
      enddo
   else
      !   Haydock_v0_mod = Bf(1)
      !   Bf(1) = 0._SP
   endif
   !
 else ! [***] Initialization Hermitian case
   !
   ! it=1:|Vm>=|q->0>/(<q->0|q->0>)^(1/2)
   !
   call K_dot_product(v0_mod_,V0,V0) 
   Haydock_v0_mod=sqrt(real(v0_mod_,SP))
   !
   if (it_on_disk==0) then
     do i_g=1,BS_nT_grps
       if (.not.PAR_IND_T_Haydock%element_1D(i_g)) cycle
       Vn(i_g)%fragment  = V0(i_g)%fragment/Haydock_v0_mod
     enddo
   endif
   !
 endif
 !
 ! [***] Loop ...
 !
 do it=it_on_disk+1,Max_iterations
   !
   reached_treshold=0._SP
   !
   if (.not.use_cpl_scheme) then
     !
     ! [***] Hermitian case: 
     !
     !|Vm+1> = H |Vm>
     !
     call  K_multiply_by_V(Vn,Vnp1,1)
     !
     ! A(n) = <Vm|Vm+1>
     !
     call K_dot_product(v0_mod_,Vn,Vnp1) 
     Af(it)=real(v0_mod_,SP)
     !
     !|Vm+1> = |Vm+1> - A(n)|Vm> - B(n)|Vm-1>
     !
     do i_g = 1,BS_nT_grps
       if (.not.PAR_IND_T_Haydock%element_1D(i_g)) cycle
       call V_by_V_plus_V_omp(BS_T_grp(i_g)%size,-Af(it)*cONE,Vn(i_g)%fragment,Vnp1(i_g)%fragment)
       call V_by_V_plus_V_omp(BS_T_grp(i_g)%size,-Bf(it)*cONE,Vnm1(i_g)%fragment,Vnp1(i_g)%fragment)
     end do
     !
     ! B(n+1)= <Vm+1|Vm+1>^(1/2)
     !
     call K_dot_product(v0_mod_,Vnp1,Vnp1) 
     Bf(it+1)=sqrt(real(v0_mod_,SP))
     if( Bf(it+1)==(Bf(it+1)+1._SP) ) call error('Bf=NaN likely because some eigenvalue of the BSE is negative.')
     !
     !|Vm-1> = |Vm>
     !
     do i_g=1,BS_nT_grps
       if (.not.PAR_IND_T_Haydock%element_1D(i_g)) cycle 
       Vnm1(i_g)%fragment  =Vn(i_g)%fragment
     enddo
     !
     !|Vm> =|Vm+1> / B(n+1)
     !
     do i_g=1,BS_nT_grps
       if (.not.PAR_IND_T_Haydock%element_1D(i_g)) cycle
       Vn(i_g)%fragment  =Vnp1(i_g)%fragment/Bf(it+1)
     enddo
     !
   else 
     !
     ! [***] Non-Hermitian case: 
     !
     !
     ! A(n) = <Vm+1|F|Vm+1> (that is <Vm|HFH|Vm>), 
     !      =  0   by symmetry 
     !
     ItParity=(-1)**it
     Af(it)=0._SP
     !
     !|Vm+1> = |Vm+1> - B(n)|Vm-1> (as Am is zero by symmetry)
     !
     do i_g = 1,BS_nT_grps
       if (.not.PAR_IND_T_Haydock%element_1D(i_g)) cycle
       call V_by_V_plus_V_omp(BS_T_grp(i_g)%size,-Bf(it)*cONE,Vnm1(i_g)%fragment,Vnp1(i_g)%fragment)
     end do
     !
     ! |Vm-1> = |Vm> 
     ! |Vm>   = |Vm+1> 
     !
     do i_g=1,BS_nT_grps
       if (.not.PAR_IND_T_Haydock%element_1D(i_g)) cycle
       Vnm1(i_g)%fragment = Vn(i_g)%fragment
       Vn(i_g)%fragment   = Vnp1(i_g)%fragment
     enddo
     !
     !|Vm+1> = H |Vm>
     !
     call K_multiply_by_V(Vn,Vnp1,ItParity)
     !
     ! B(n+1)= <Vm|F|Vm+1>^(1/2) (that is <Vm|FH|Vm>^(1/2))
     !       = (2*Re(<Vm|Vmp1>))^(1/2) by symmetry, 
     !          where the dot_product is just on eh pair space 
     !
     call K_dot_product(v0_mod_,Vn,Vnp1) 
     Bf(it+1)=sqrt(2._SP*real(v0_mod_,SP))
     ! Simple test for INF
     if( Bf(it+1)==(Bf(it+1)+1._SP) ) call error('Bf=INF likely because some eigenvalue of the BSE is negative.')
     ! Tests for NaN
     if (NAN(Bf(it+1)))  call error(' Bf=NaN likely because some eigenvalue of BSE is negative.')
     !
     !|Vm> =|Vm+1> / B(n+1)
     !
     do i_g=1,BS_nT_grps
       if (.not.PAR_IND_T_Haydock%element_1D(i_g)) cycle
       Vnp1(i_g)%fragment  =Vnp1(i_g)%fragment/Bf(it+1)
       Vn(i_g)%fragment    =Vn(i_g)%fragment/Bf(it+1)
     enddo
     !
     ! Using symmetry arguments
     ! Cf=(1-ItParity)Re(<dipoles|Vm>) + i*(1+ItParity)Im(<dipoles|Vm>) 
     ! with all product evaluated just in the eh pairs subspace 
     !
     call K_dot_product(v0_mod_,V0,Vn) 
     Cf(it+1)= ((1._SP-real(ItParity,SP))*real(v0_mod_,SP))/Haydock_v0_mod
     !
     !
   endif
   !
   if (it>2) then
     !
     if (use_cpl_scheme) then 
       call build_L_and_check_convergence(Af(:it),Bf(:it+1),it,1,Cf(:it))
     else
       call build_L_and_check_convergence(Af(:it),Bf(:it+1),it,1)
     end if
     !
     !
     BSS_description(BSS_n_descs-1)='        |Accuracy (reached)   [o/o]:'//&
&                                    trim(real2ch(reached_treshold))
     BSS_description(BSS_n_descs)='        |Iteration                 :'//trim(intc(it))
     !
     call K_output_file(iq,"Haydock")
     dumb_ch='[Haydock] Iteration '//trim(intc(it))//' Accuracy :'//&
&            trim(real2ch(reached_treshold))//'|'//trim(real2ch(Haydock_treshold))
     if (tty_size>0.and.it_on_disk==0) call LIVE_message(dumb_ch,"r","","%s")
     if (tty_size>0.and.it_on_disk> 0) call LIVE_message(dumb_ch,"n","","%s")
     if (tty_size<0) call LIVE_message(dumb_ch,"n","","%s")
   else
     !
     dumb_ch='[Haydock] Iteration '//trim(intc(it))
     if (tty_size<0) call LIVE_message(dumb_ch,"n","","%s")
     if (tty_size>0.and.it==1) call LIVE_message(dumb_ch,"n","","%s")
     if (tty_size>0.and.it==2) call LIVE_message(dumb_ch,"n","","%s")
     !
   endif
   !
   ! Haydock Coefficients and restart vectors on disk
   !--------------------------------------------------
   !call io_control(ACTION=OP_WR_CL,SEC=(/1,2/),ID=ID)
!   if (use_cpl_scheme) then
!     Bf(1) = Haydock_v0_mod
 !
 !
!      io_err=io_BSS_Haydock(ID,it,BS_K_dim,reached_treshold,  &
! &                          Af(:it),Bf(:it+1),Vmm1,Vm,Vnp1=Vmp1,Cf=Cf(:it+1))
 !
 !
!     Bf(1) = 0._SP
!   else
!     io_err=io_BSS_Haydock(ID,it,BS_K_dim,reached_treshold,Af(:it),Bf(:it+1),Vmm1,Vm)
!   end if
!   !
   if ( (reached_treshold>0.and.reached_treshold<abs(Haydock_treshold)) .or. &
&       stop_now(.FALSE.)) then
     call msg('r','Accuracy (reached)   [o/o]:',reached_treshold)
     call msg('r','Iterations                :',it)
     exit
   endif
   !
 enddo
 !
 ! CLEAN
 !=======
 !
 call BS_HAYVEC_free(Vn)
 call BS_HAYVEC_free(Vnp1)
 call BS_HAYVEC_free(Vnm1)
 deallocate(Vn,Vnp1,Vnm1)
 !
 if (use_cpl_scheme)  then
   call BS_HAYVEC_free(V0)
   if (allocated(V0)) deallocate(V0)
   if (allocated(Cf)) deallocate(Cf)
   !
   !
 end if
 !
#if defined _TIMING
 call timing('Haydock Solver',OPR='stop')
#endif
 !
 contains
   !
   subroutine build_L_and_check_convergence(Af,Bf,it,ii,Cf)
     implicit none
     integer,    intent(in)          :: it,ii
     real(SP),   intent(in)          :: Bf(it+1),Af(it)
     complex(SP),intent(in),optional :: Cf(it)
     !
     ! Work Space
     !
     integer     :: i1,iw,i_eps(2)
     real(SP)    :: Co,tmp_tresh,den
     !
     complex(SP) :: factor_jj(2)
     complex(SP) :: gauge_factor
     !
     complex(SP) :: X_o(4,it), YbyX(2)
     complex(SP),allocatable :: X_i(:,:)
     !
     ! related to terminator
     !
     complex(SP) :: X_t(2)
     real(SP)    :: Av1, Av2
     integer, parameter :: RES = 3, ARES = 2, COUPL = 1, MIN_ITER = 10
     logical     :: UseTerminator
     logical     :: retarded, coupling
     !
     Co=Co_factor*Haydock_v0_mod**2._SP
     !
     X_t =cZERO
     UseTerminator = .false.  
     !
     retarded  = (trim(BSE_mode)=='retarded'.and..not.use_cpl_scheme)
     coupling= use_cpl_scheme
     !
     i_eps(1)=2
     i_eps(2)=4
     !
     if(trim(global_gauge)=='length'  ) then
       factor_jj=0._SP
       gauge_factor=cONE*Co/q_norm(1)**2
     endif
     !
     if (it > MIN_ITER.and.Haydock_terminator) UseTerminator = .true.
     if (coupling) allocate(X_i(2,it))
     if (Useterminator) then 
       if (.not.coupling) then
         Av1 = 0._SP
         Av2 = 0._SP
         do i1 = 1, it
           Av1 = Av1 + Af(i1)
           Av2 = Av2 + Bf(i1)
         end do
         Av1 = Av1/it
         Av2 = Av2/it
       else
         Av1 = 0._SP
         Av2 = 0._SP
         do i1 = 2,it+1,2
           Av1 = Av1 + Bf(i1)
           Av2 = Av2 + Bf(i1+1)
         end do
         Av1 = Av1/(it/2+mod(it,2))
         Av2 = Av2/(it/2)
       end if
     end if
     !
     do iw=1,W%n_freqs
       X_o=cZERO
       if (UseTerminator) then 
         if (.not.coupling) then
           X_t(1) = terminator(W%p(iw), Av1,Av2, RES)
           if (retarded) X_t(2) = terminator(W%p(iw),-Av1,Av2,ARES)
         endif
         if (coupling.and.(mod(it,2)==0)) X_t(1) = terminator(W%p(iw),Av1,Av2,COUPL)
         if (coupling.and.(mod(it,2)==1)) X_t(1) = terminator(W%p(iw),Av2,Av1,COUPL)
       endif
       X_o(1:2,it) = 1._SP/(W%p(iw)-Af(it)-Bf(it+1)**2*X_t(1))
       if (retarded) X_o(3:4,it)= 1._SP/(W%p(iw)+Af(it)-Bf(it+1)**2*X_t(2))
       do i1=it-1,1,-1
         X_o(1,i1) = 1._SP/(W%p(iw)-Af(i1)-Bf(i1+1)**2*X_o(1,i1+1) )
         if (retarded) X_o(3,i1)= 1._SP/(W%p(iw)+Af(i1)-Bf(i1+1)**2*X_o(3,i1+1))
       enddo
       do i1=it-2,1,-1
         X_o(2,i1) = 1._SP/(W%p(iw)-Af(i1)-Bf(i1+1)**2*X_o(2,i1+1) )
         if (retarded) X_o(4,i1)= 1._SP/(W%p(iw)+Af(i1)-Bf(i1+1)**2*X_o(4,i1+1))
       enddo
       if (coupling) then
         X_i(:,1) = -X_o(:2,1)
         X_i(:,2) = -Bf(2)*X_o(:2,2)*X_i(:,1)
         YbyX(:) = X_i(:,1)*Cf(1) + X_i(:,2)*Cf(2)
         do i1 = 2,it-1
           X_i(1,i1+1) = -Bf(i1+1)*X_o(1,i1+1)*X_i(1,i1)
           YbyX(1) = YbyX(1) + Cf(i1+1)*X_i(1,i1+1)
         end do
         do i1 = 2,it-2
           X_i(2,i1+1) = -Bf(i1+1)*X_o(2,i1+1)*X_i(2,i1)
           YbyX(2) = YbyX(2) + Cf(i1+1)*X_i(2,i1+1)
         end do
         X_o(:2,1) = YbyX(:)
       endif
       Epsilon_ii(iw,1)=W%p(iw)
       !
       !
       select case(ii)
       case(1)
         if (.not.retarded) Epsilon_ii(iw,i_eps(:))=-(X_o(1:2,1)           )
         if (     retarded) Epsilon_ii(iw,i_eps(:))=-(X_o(1:2,1)-X_o(3:4,1))
       case(2)
         if (.not.retarded) Epsilon_ij(iw,i_eps(:))=-(X_o(1:2,1)           )
         if (     retarded) Epsilon_ij(iw,i_eps(:))=-(X_o(1:2,1)-X_o(3:4,1))
       end select
       !
     enddo
     !
     do iw=1,W%n_freqs
       !
       !
       
       if (ii==1) Epsilon_ii(iw,i_eps(:))=Epsilon_ii(iw,i_eps(:))*gauge_factor
       if (ii==2) Epsilon_ij(iw,i_eps(:))=Epsilon_ij(iw,i_eps(:))*gauge_factor
       
       !
       if (ii==1) Epsilon_ii(iw,i_eps(:))=1._SP+Epsilon_ii(iw,i_eps(:))+X_drude_term(iw)*gauge_factor
       !
       !
       select case(ii)
       case(1)
         den=abs(Epsilon_ii(iw,2)+Epsilon_ii(iw,2))/2._SP
         tmp_tresh=abs(Epsilon_ii(iw,2)-Epsilon_ii(iw,4))/den
       case(2)
         den=abs(Epsilon_ij(iw,2)+Epsilon_ij(iw,2))/2._SP
         tmp_tresh=abs(Epsilon_ij(iw,2)-Epsilon_ij(iw,4))/den
       end select
       !
       if (Haydock_treshold>0._SP .and. den>0._SP ) reached_treshold=max(reached_treshold,tmp_tresh)
       if (Haydock_treshold<0._SP .and. den>0._SP ) reached_treshold=reached_treshold+tmp_tresh/real(W%n_freqs)
       !
     enddo
     !
     if (use_cpl_scheme) deallocate(X_i)
     !
   end subroutine
   !
   function terminator(x,c1,c2,which)
     !
     complex(SP) :: terminator, f, g, x
     real(SP) :: c1,c2
     integer  :: which
     !
     select case(which)
     case (1) 
       f = x**2 - c1**2 + c2**2
       g = 2._SP*x*c2**2
       terminator = f + sqrt(f**2 -2._SP*x*g) 
       terminator = terminator/g
     case (2)
       f = (x+c1)
       terminator = f + sqrt(f**2 -4._SP*c2**2.)
       terminator = terminator/2._SP/c2**2
     case (3)
       f = (x-c1)
       terminator = f + sqrt(f**2 -4._SP*c2**2.)
       terminator = terminator/2._SP/c2**2
     end select
   end function terminator
   !
end subroutine
