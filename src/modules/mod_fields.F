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
module fields
 !
 use pars, ONLY:SP,schlen,lchlen,pi
 use units,ONLY:HA2EV,FS2AUT,HBAR_eVfs
 !
 implicit none
 !
 ! Electric Field(s)
 ! 
 type ext_field
   character(schlen) :: ef_name
   character(schlen) :: ef_pol
   real(SP) :: t_initial
   integer  :: t_initial_indx    ! time index of extern field switch on  (input variable)
   real(SP) :: t_final
   integer  :: t_final_indx      ! time index of extern field switch off (computed in RT_Fluence)
   real(SP) :: frequency
   real(SP) :: damping
   real(SP) :: fluence = 0._SP
   real(SP) :: intensity
   real(SP) :: amplitude
   real(SP) :: versor(3)
   real(SP) :: versor_circ(3)
 end type ext_field
 !
 integer, parameter  :: n_ext_fields_max=4
 integer             :: n_ext_fields    =0
 type(ext_field), save :: Efield(n_ext_fields_max)
 !
 ! Vector potential
 ! 
 type gauge_field
   complex(SP) :: vecpot(3)
   complex(SP) :: vecpot_vel(3)
   complex(SP) :: vecpot_acc(3)
   real(SP)    :: fluence
   real(SP)    :: intensity
 end type gauge_field
 !
 type(gauge_field) :: A_vecpot
 type(gauge_field) :: A_vecpot_previous
 type(gauge_field) :: A_ext
 type(gauge_field) :: A_ind
 type(gauge_field) :: A_ind_previous
 !
 contains
   !
   logical function field_is_ok(E_field)
     type(ext_field)   ::E_field
     field_is_ok= any((/ trim(E_field%ef_name) == 'SIN' ,&
&                        trim(E_field%ef_name) == 'SOFTSIN' ,& 
&                        trim(E_field%ef_name) == 'ANTIRES' ,& 
&                        trim(E_field%ef_name) == 'RES' ,& 
&                        trim(E_field%ef_name) == 'DELTA' ,& 
&                        trim(E_field%ef_name) == 'GAUSS' ,& 
&                        trim(E_field%ef_name) == 'THETA' ,& 
&                        trim(E_field%ef_name) == 'PULSE' ,& 
&                        trim(E_field%ef_name) == 'QSSIN' /)) .and. &
&                 any((/ trim(E_field%ef_pol)  == 'linear' ,&
&                        trim(E_field%ef_pol)  == 'circular' /))
   end function
   !
   real(SP) function EtoT(E,T)
     real(SP), optional ::T
     real(SP), optional ::E
     if (present(T)) EtoT=2._SP*pi*HBAR_eVfs/(T*HA2EV)*FS2AUT
     if (present(E)) EtoT=2._SP*pi*HBAR_eVfs/(E*HA2EV)*FS2AUT
   end function
   !
   function small_a(T_i,E_field,order)
     !
     ! The vector potential is generally written as
     !
     !  order=0  A (t)=-cEo  a (t) theta(t)
     !  order=1  A'(t)=-cEo (a'(t) theta(t)+a (t) delta(t))
     !  order=2  A"(t)=-cEo (a"(t) theta(t)+a'(t) delta(t)-a(t) sign(t))
     !
     ! the functions theta,delta and sign can be the standard distributions
     ! or more fancy functions that can mimic the distributions.
     !
     ! Note that A is evolved using A''(t) starting from A(0) and A'(0). 
     !
     use pars,      ONLY:cI,cZERO,pi
     type(ext_field)   ::E_field
     !
     real(SP)          ::T_i
     integer           ::order
     !
     real(SP)          ::damp_func,a,b,c
     complex(SP), dimension(2) :: small_a
     !
     integer           ::i_fr,i_field,n_fields
     real(SP)          ::T_0,W_0,W_i,sigma,WT_i,EXPf,fr_shift(2),T_eff
     complex(SP)       ::f_t(2),f_tmp(3)
     !
     small_a=cZERO
     !
     W_0=E_field%frequency
     sigma=E_field%damping
     T_0=pi/W_0*(real(nint(W_0/pi*3._SP*sigma),SP))
     f_t=cZERO
     fr_shift(1)=0._SP
     fr_shift(2)=pi/2._SP
     !
     if(trim(E_field%ef_pol)=="linear"  ) n_fields=1
     if(trim(E_field%ef_pol)=="circular") n_fields=2
     !
     do i_field=1,n_fields
       !
       select case( trim(E_field%ef_name) )
       case('STATIC')
         if (order==0 ) f_t(i_field)=T_i
         if (order==1 ) f_t(i_field)=1._SP
         if (order==2 ) f_t(i_field)=0._SP
       case('SIN')
         W_i=E_field%frequency
         WT_i=W_i*T_i+fr_shift(i_field)
         if (order==0 ) f_t(i_field)=f_t(i_field)-    (cos(WT_i)-1._SP)/W_i
         if (order==1 ) f_t(i_field)=f_t(i_field)+     sin(WT_i)
         if (order==2 ) f_t(i_field)=f_t(i_field)+W_0* cos(WT_i)
       case('SOFTSIN')
         T_0=sigma
         !
         a =  3._SP/T_0**4 
         b = -8._SP/T_0**3
         c =  6._SP/T_0**2
         !
         damp_func=1._SP
         if(real(T_i)<T_0.and.T_0>0._SP) damp_func=(a*T_i**4 + b*T_i**3 + c*T_i**2)       
         !
         W_i=E_field%frequency
         WT_i=W_i*T_i+fr_shift(i_field)
         !
         if (order==0 ) f_t(i_field)=f_t(i_field)- damp_func*(cos(WT_i)-1._SP)/W_i
         if (order==1 ) f_t(i_field)=f_t(i_field)+ damp_func*sin(WT_i)
         if (order==2 ) f_t(i_field)=f_t(i_field)+ damp_func*W_0*cos(WT_i)
         if (order==-1) f_t(i_field)=-2
         !
       case('THETA')
         !  
         T_0=sigma
         !
         a =  3._SP/T_0**4 
         b = -8._SP/T_0**3
         c =  6._SP/T_0**2
         !
         damp_func=1._SP
         if(real(T_i)<T_0.and.T_0>0._SP) damp_func=(a*T_i**4 + b*T_i**3 + c*T_i**2)       
         !
         if (order==0 ) f_t(i_field)=damp_func*T_i
         if (order==1 ) f_t(i_field)=damp_func
         if (order==2 ) f_t(i_field)=0._SP
         !
       case('ANTIRES')
         W_i=E_field%frequency
         WT_i=W_i*T_i+fr_shift(i_field)
         if (order==0 ) f_t(i_field)=f_t(i_field)-cI*    exp(cI*WT_i)/W_i
         if (order==1 ) f_t(i_field)=f_t(i_field)+       exp(cI*WT_i)
         if (order==2 ) f_t(i_field)=f_t(i_field)+cI*W_i*exp(cI*WT_i)
         !
       case('RES')
         W_i=E_field%frequency
         WT_i=W_i*T_i+fr_shift(i_field)
         if (order==0 ) f_t(i_field)=f_t(i_field)+cI*    exp(-cI*WT_i)/W_i
         if (order==1 ) f_t(i_field)=f_t(i_field)-       exp(-cI*WT_i)
         if (order==2 ) f_t(i_field)=f_t(i_field)-cI*W_i*exp(-cI*WT_i)
         !
       case('DELTA')
         if (order==0 ) f_t(i_field)=1._SP
         if (order> 0 ) f_t(i_field)=0._SP
         if (order==-1) f_t(i_field)=1._SP
         !
       case('GAUSS')
         if (order==0 ) f_t(i_field)= sigma*sqrt(pi/2._SP)* ( erf( (T_i-T_0)/(sigma*sqrt(2._SP)) )+1._SP )
         if (order==1 ) f_t(i_field)= exp(-(T_i-T_0)**2/(2._SP*sigma**2) )
         if (order==2 ) f_t(i_field)=-exp(-(T_i-T_0)**2/(2._SP*sigma**2) )*(T_i-T_0)/sigma**2
         !
       case('QSSIN')
         WT_i=W_0*(T_i-T_0)+fr_shift(i_field)
         EXPf=exp(-(T_i-T_0)**2/(2._SP*sigma**2) )
         if (order==0 ) f_t(i_field)=0._SP
         if (order==1 ) f_t(i_field)=     sin(WT_i)                              *EXPf
         if (order==2 ) f_t(i_field)=(W_0*cos(WT_i)-(T_i-T_0)*sin(WT_i)/sigma**2)*EXPf
         ! 
       case('PULSE')
         !
         T_0=sigma
         !
         a =  3._SP/(T_0/2._SP)**4 
         b = -8._SP/(T_0/2._SP)**3
         c =  6._SP/(T_0/2._SP)**2
         !
         if(real(T_i)<=T_0/2._SP) then
           damp_func=(a*T_i**4 + b*T_i**3 + c*T_i**2)       
         else if(real(T_i)>T_0/2._SP.and.real(T_i)<=T_0) then 
           damp_func=(a*(T_0-T_i)**4 + b*(T_0-T_i)**3 + c*(T_0-T_i)**2)       
         else
           damp_func=0._SP
         endif
         !
         W_i=E_field%frequency
         WT_i=W_i*T_i+fr_shift(i_field)
         !
         if (order==0 ) f_t(i_field)=f_t(i_field)- damp_func*(cos(WT_i)-1._SP)/W_i
         if (order==1 ) f_t(i_field)=f_t(i_field)+ damp_func*sin(WT_i)
         if (order==2 ) f_t(i_field)=f_t(i_field)+ damp_func*W_0*cos(WT_i)
         if (order==-1) f_t(i_field)=-2
         !
       end select
       !
     enddo
     !
     small_a=f_t
     !
   end function small_a
   !
   complex(SP) function small_a_frequency(W_i,E_field,iErr)
     !
     use pars,      ONLY:cZERO,cI,pi
     type(ext_field)   ::E_field
     complex(SP)       ::W_i
     integer           ::iErr
     !
     integer           ::i_f
     real(SP)          ::W_0
     complex(SP)       ::local_a
     !
     if(trim(E_field%ef_name)=="circular") then
       iErr=-1
       small_a_frequency=cZERO
       return
     endif
     !
     local_a=cZERO
     !
     W_0=E_field%frequency
     select case( trim(E_field%ef_name) )
     case('SIN')
       local_a=local_a+   (1._SP/(W_i-W_0)-1._SP/(W_i+W_0))/2._SP-1._SP/W_0
     case('ANTIRES')
       local_a=local_a+cI*(               -1._SP/(W_i+W_0)       -1._SP/W_0)
     case('RES')
       local_a=       -cI*(1._SP/(W_i-W_0)                       -1._SP/W_0)
     case('DELTA')
       local_a=1._SP
     case('GAUSS')
       iErr=-1
     case('QSSIN')
       iErr=-1
     case('PULSE')
       iErr=-1
     end select
     !
     small_a_frequency=local_a
     !
   end function small_a_frequency
   !
   subroutine Efield_duplicate(E1,E2)
     type(ext_field) :: E1,E2
     E2%t_initial=E1%t_initial  
     E2%t_initial_indx=E1%t_initial_indx  
     E2%t_final=E1%t_final  
     E2%t_final_indx=E1%t_final_indx  
     E2%frequency=E1%frequency  
     E2%damping=E1%damping  
     E2%intensity=E1%intensity  
     E2%amplitude=E1%amplitude  
     E2%versor=E1%versor
     E2%versor_circ=E1%versor_circ
     E2%ef_name=E1%ef_name
     E2%ef_pol=E1%ef_pol
   end subroutine
   !
   subroutine Efield_reset(E)
     type(ext_field) :: E
     E%t_initial    =0._SP
     E%t_initial_indx=2
     E%t_final      =0._SP
     E%t_final_indx =0
     E%frequency    =0._SP
     E%intensity    =0._SP
     E%damping      =0._SP
     E%ef_name      ='none'
     E%ef_pol       ='none'
     E%versor       =(/1._SP,0._SP,0._SP/)
     E%versor_circ  =(/0._SP,1._SP,0._SP/)
   end subroutine
   !
   subroutine A_vecpot_reset(A)
     type(gauge_field) A
     A%vecpot_acc=0._SP
     A%vecpot_vel=0._SP
     A%vecpot    =0._SP
   end subroutine
   !
   complex(SP) function Rabi_Factor(Field,P,R)
     use X_m,       ONLY:global_gauge
     !
     ! Rabi=2 * \mu.E
     !
     ! E is the field amplitude = sqrt ( I *8*pi/c  ) 
     !
     ! I is given in the input file
     !
     use pars, ONLY: cI
     type(ext_field), intent(in) :: Field
     complex(SP)                 :: P(3),R(3)
     if ( trim(global_gauge)=='length' ) then
       Rabi_Factor=2._SP*sum(R(:)*Field%versor(:))*Field%amplitude
     else 
       Rabi_Factor=2._SP*sum(P(:)*Field%versor(:))*Field%amplitude
       if( any( trim(Field%ef_name)==(/'ANTIRES','SIN    '/)) ) Rabi_Factor=-cI*Rabi_Factor/Field%frequency
       if( any( trim(Field%ef_name)==(/'RES'/)) )               Rabi_Factor= cI*Rabi_Factor/Field%frequency
     endif
   end function Rabi_Factor
   !
   complex(SP) function Divide_by_Field(Field,order)
     !
     use pars, ONLY: cI,pi
     type(ext_field):: Field
     integer        :: order
     ! work space
     complex(SP) :: E_w
     real(SP)    :: T_0, sigma, W_0, T
     !
     select case(Field%ef_name)
       case('ANTIRES')
         if (order/=0) Divide_by_Field =(1._SP,0._SP)/Field%amplitude**order
         if (order==0) Divide_by_Field =(1._SP,0._SP)/Field%amplitude**2
       case('SIN','SOFTSIN')
         Divide_by_Field =  (-2._SP*cI/Field%amplitude)**order
         if (order==0) Divide_by_Field =  (4._SP,0._SP)/Field%amplitude**2
       case('QSSIN') !Approximate relations/does not work yet
         sigma=Field%damping
         T_0=10._SP*sigma
         W_0=Field%frequency
         T = 2._SP*pi/W_0
         E_w= sqrt(pi/2._SP)*Field%amplitude*sigma*exp(-cI*W_0*T_0)*&
              &(erf((T-T_0)/sqrt(2._SP)/sigma)+erf(T_0/sqrt(2._SP)/sigma))
         if (order/=0) Divide_by_Field =  (2._SP*cI/E_w)**order
         if (order==0) Divide_by_Field =  (4._SP,0._SP)/(E_w*conjg(E_w))
       end select
       !
   end function Divide_by_Field
   !
   real(SP) function Efield_strength(Intensity,unit_system)
     ! 
     ! From Octopus ( http://www.tddft.org/programs/octopus )
     !
     ! It is very common to describe the strength of a laser field by it intensity, 
     ! rather than using the electric field amplitude. In atomic units, the relationship 
     ! between instantaneous electric field and intensity is:
     !
     ! I(t) = \frac{c}{8\pi} E^2(t)
     !
     ! It is common to read intensities in kW cm^-2. The dimensions of intensities are [W]/(L^2T), 
     ! where [W] are the dimensions of energy. The relevant conversion factors are:
     !
     ! Hartree / (a_0^2 atomic_time) = 6.4364086e+15 W / cm^2 = 6.4364086e+12 kW / cm^2
     !
     ! In Yambo AU2KWCMm2=6.4364086e+12
     !
     !--------------------------------------------------------------------------------------------
     !
     ! This simple function uses the formula valid in SI and CGS to extract 
     ! the Field intensity given in au
     !
     use units,ONLY:AU2KWCMm2,SPEED_OF_LIGHT_SI,FREE_SPACE_PERM,VMm12AU,WMm22KWCMm2,&
&                   WMm22ERGCMm2SECm1,SVCMm12VMm1,SPEED_OF_LIGHT
     implicit none
     !
     real(SP)     :: Intensity
     character(*) :: unit_system
     !
     ! Work Space
     !
     real(SP) :: SPEED,I
     !
     ! From Boyd, "Non linear optics", 3rd edition, page 602,603
     !
     ! Assuming n=1 (epsilon=1)
     !
     if (unit_system=="SI") then
       !
       I=Intensity*AU2KWCMm2/WMm22kWCMm2
       !
       SPEED=SPEED_OF_LIGHT_SI
       !
       ! I = 1 FREE_SPACE_PERM SPEED_OF_LIGHT |E|^2 
       !
       Efield_strength= sqrt(I/1._SP/FREE_SPACE_PERM/SPEED)*VMm12AU
       !
     endif
     !
     if (unit_system=="CGS") then
       !
       I=Intensity*AU2KWCMm2/WMm22kWCMm2/WMm22ERGCMm2SECm1
       !
       SPEED=SPEED_OF_LIGHT_SI*100._SP ! cm/sec
       !
       ! I = SPEED_OF_LIGHT/4/pi |E|^2 
       !
       Efield_strength= sqrt(I*4._SP*pi/SPEED)*SVCMm12VMm1*VMm12AU
       !
     endif
     !
     if (unit_system=="AU") then
       !
       I=Intensity
       !
       SPEED=SPEED_OF_LIGHT
       !
       ! I = SPEED_OF_LIGHT/4/pi |E|^2 
       !
       Efield_strength= sqrt(I*4._SP*pi/SPEED)
       !
     endif
     !
   end function
   !
end module
