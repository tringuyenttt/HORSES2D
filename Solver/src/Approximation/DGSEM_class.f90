!
!/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
!
!      DGSEM_class.f90
!      Created: 2015-09-26 12:05:17
!      REV:     2016-02-24 21:16:23
!      By: Juan MANZANERO
!
!/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
!


!   *****************
    module DGSEM_class
!   *****************

!   ------------
!   Modules used
!   ------------
    use SMConstants
    use Physics
    use NodesAndWeights_class
    use QuadMeshClass
    use MeshFileClass
    use DGSpatialDiscretizationMethods
    use DGTimeIntegrator
    use Storage_module
    use DGBoundaryConditions
    implicit none

    integer, parameter           :: STR_LEN_DGSEM = 128

!   ---------------
!   type DEFINITION
!   ---------------
    type DGSEM_t
        type(QuadMesh_t)                    :: mesh
        type(NodalStorage)                  :: spA             ! Interpolation nodes and weights structure
        class(NodesAndWeights_t),   pointer :: spI => NULL()   ! Integration nodes and weights structure
        type(Storage_t)                     :: Storage
        class(BoundaryCondition_t), pointer :: BoundaryConditions(:)
        type(TimeIntegrator_t)              :: Integrator
        contains
            procedure       :: construct => DGSEM_construct
            procedure       :: SetInitialCondition => DGSEM_SetInitialCondition
            procedure       :: Integrate => DGSEM_Integrate
    end type DGSEM_t

    private
    public DGSEM_t , DGSEM_Initialize
!   --------------------
!   Internal subroutines
!   --------------------
    CONTAINS


!   ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
!                       CONSTRUCTION subroutines
!   ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        function DGSEM_Initialize() result(sem)
            type(DGSEM_t)         :: sem
!
!           *********************************
!           Initialize mesh and Nodal Storage
!           *********************************
!
            sem % mesh = InitializeMesh()
            sem % spA  = newNodalStorage()
    
            sem % Storage = newStorage()
             
        end function DGSEM_Initialize
         
        subroutine DGSEM_construct( self ,  meshFile )
            use Setup_class
            use QuadElementClass
            implicit none
            class(DGSEM_t)                                               :: self
            class(MeshFile_t)                                            :: meshFile
!           ----------------------------------------------------------------------------------------------
            integer                                                      :: total_polyorder
            integer                                                      :: eID
            integer                                                      :: iBC
            integer                                                      :: fID
            class(Edge_t), pointer                                       :: face
!
!           ***********************************************
!           Allocate memory for solution and its derivative
!           ***********************************************
!
            allocate ( self % Storage % Q    ( NEC * meshFile % cumulativePolynomialOrder ( meshFile % no_of_elements        )  )  ) 
            allocate ( self % Storage % QDot ( NEC * meshFile % cumulativePolynomialOrder ( meshFile % no_of_elements )  )  ) 
            allocate ( self % Storage % dQ   ( NDIM * NEC * meshFile % cumulativePolynomialOrder ( meshFile % no_of_elements        )  )  ) 
                
            if (Setup % inviscid_discretization .eq. "Over-Integration") then
               allocate ( self % Storage % F   ( NDIM * NEC * meshFile % no_of_elements * ( setup % integration_points + 1)**2    ) )
            else
               allocate ( self % Storage % F   ( NDIM * NEC * meshFile % cumulativePolynomialOrder ( meshFile % no_of_elements )  )  ) 
            end if

!
!           ******************
!           Construct the mesh
!           ******************
!
            if (Setup % inviscid_discretization .eq. "Over-Integration") then
               allocate( self % spI )
               call self % spI % init( Setup % integration_points , Setup % nodes )
            end if

            call self % mesh % constructFromFile(meshFile , self % spA , self % Storage , self % spI)
!
!           ********************************
!           Construct the integration points
!           ********************************
!
            if (Setup % inviscid_discretization .eq. "Over-Integration") then
!          
!              Set the interpolation matrices
!
               call self % spA % computeInterpolationMatrices( self % spI )

            end if
              
!
!           ***************************
!           Set the boundary conditions
!           ***************************
!
            call self % mesh % ConstructZones( meshFile )
!
!           ***************
!           Prepare methods
!           ***************
!
            call DGSpatial_Initialization() 
            
        end subroutine DGSEM_construct
            
        subroutine DGSEM_SetInitialCondition( self )
            use Setup_class
            implicit none
            class(DGSEM_t)                   :: self

            call self % mesh % SetInitialCondition ()

        end subroutine DGSEM_SetInitialCondition
      
        subroutine DGSEM_Integrate( self )
            implicit none
            class(DGSEM_t)                   :: self

            self % Integrator = NewTimeIntegrator()
            call self % Integrator % Describe()

            call self % Integrator % Integrate( self % mesh , self % Storage)

      end subroutine DGSEM_Integrate

end module DGSEM_class
