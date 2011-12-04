/*
 * fieldclass header file
 */

//#include "cuda.h"
//#include "cuda_runtime.h"
//#include "builtin_types.h"
#include "texture_refs.cuh"

typedef struct __align__(16) BCspline
{
public:
	realkind coeff[4];

	__host__ __device__
	realkind & operator[](int idx)
	{
		return coeff[idx];
	};

	__host__ __device__
	const realkind & operator[](int idx)
	const
	{
		return *(const realkind*)(&coeff[idx]);
	};

}BCspline;

typedef struct __align__(32) BCsplined
{
public:
	double coeff[4];

	__host__ __device__
	double & operator[](int idx)
	{
		return coeff[idx];
	};

	__host__ __device__
	const double & operator[](int idx)
	const
	{
		return *(const double*)(&coeff[idx]);
	};

}BCsplined;


enum XPgridlocation
{
	XPgridlocation_host = 0,
	XPgridlocation_device = 1
};

enum XPgridderiv
{
	XPgridderiv_f = 0,
	XPgridderiv_dfdx = 1,
	XPgridderiv_dfdy = 2,
	XPgridderiv_dfdxx = 3,
	XPgridderiv_dfdyy = 4,
	XPgridderiv_dfdxy = 5

};

enum XPTextureGridType
{
	crossSection = 0,
	XPtex1DLayered = 1,
	XPtex2D = 2
};

typedef struct XPGridParams
{
public:
	int griddims[6];
	realkind gridspacing[6];
	realkind origin[6];

}XPGridParams;

class XPTextureSpline
{
public:
	BCspline* spline; // dummy spline
	texFunctionPtr pt2Function;
	int2 griddims;
	realkind2 gridspacing;
	realkind2 origin; //  x[0][0], y[0][0]
	size_t pitch;
	__host__ __device__
	XPTextureSpline(){;}

	__host__
	void allocate(int2 griddims_in,enum XPgridlocation location_in);
	__host__
	void setup(double* spline_in,realkind xmin,realkind xmax,realkind ymin,realkind ymax);

	__host__
	void fill2DLayered(cudaMatrixr data_in);

	__device__
	void allocate_local(BCspline* spline_local);
	// Find the cell index of a given x and y.
	__device__
	void shift_local(XPTextureSpline grid_in,int nx,int ny);
	__device__
	int2 findindex(realkind px,realkind py);
	// Evaluate the spline at the given location
	template<enum XPgridderiv ideriv>
	__device__
	realkind BCspline_eval(realkind px,realkind py);

	__device__
	realkind get_spline(int nx,int ny,int coeff)
	{

		return pt2Function(nx,ny,coeff);

		//return *((const BCspline*)((char*)spline+ny*pitch)+nx);
	}

	__host__
	void XPTextureSplineFree(void)
	{
		printf("Freeing XPTextureSpline\n");
		char* texrefstring = (char*)malloc(sizeof(char)*30);
		sprintf(texrefstring,"texref2DLayered%i",my_array_reference);

		const textureReference* texRefPtr;
		CUDA_SAFE_CALL(cudaGetTextureReference(&texRefPtr, texrefstring));
		CUDA_SAFE_CALL(cudaUnbindTexture(texRefPtr));
		CUDA_SAFE_CALL(cudaFreeArray(cuArray));

	}

private:
	enum XPgridlocation location;
	const char* symbol;
	cudaArray* cuArray;
	int my_array_reference;

};


class XPgrid
{
public:
	BCspline* spline;
	int2 griddims;
	realkind2 gridspacing;
	realkind2 origin; //  x[0][0], y[0][0]
	size_t pitch;
	__host__ __device__
	XPgrid(){;}

	__host__
	void allocate(int2 griddims_in,enum XPgridlocation location_in);
	__host__
	void setup(double* spline_in,realkind xmin,realkind xmax,realkind ymin,realkind ymax);

	__device__
	void allocate_local(BCspline* spline_local);
	// Find the cell index of a given x and y.
	__device__
	void shift_local(XPgrid grid_in,int nx,int ny);
	__device__
	int2 findindex(realkind px,realkind py);
	// Evaluate the spline at the given location
	template<enum XPgridderiv ideriv>
	__device__
	realkind BCspline_eval(realkind px,realkind py);
	__device__
	BCspline & get_spline(int nx,int ny)
	{
		nx = max(0,min(nx,(griddims.x-1)));
		ny = max(0,min(ny,(griddims.y-1)));

		unsigned int index = zmap(nx,ny);
		return spline[index];
		//return *((BCspline*)((char*)spline+ny*pitch)+nx);
	}
	__device__
	const BCspline & get_spline(int nx,int ny)
	const
	{
		nx = max(0,min(nx,(griddims.x-1)));
		ny = max(0,min(ny,(griddims.y-1)));

		unsigned int index = zmap(nx,ny);
		return spline[index];

		//return *((const BCspline*)((char*)spline+ny*pitch)+nx);
	}

private:
	enum XPgridlocation location;

};

class XPgrid_polar: public XPgrid
{
public:
	int m;
	int n;
	cudaMatrixr splinecoeff;
	cudaMatrixr xgrid;
	cudaMatrixr ygrid;
	realkind xspani;
	realkind yspani;
	int ii; //ii[vectorlength]
	int jj; // jj[vectorlength]
	realkind hx; // hx(vectorlength]
	realkind hy; // hy[vectorlength]
	realkind hxi; // hxi[vectorlength]
	realkind hyi; // hyi[vectorlength]

	__host__ __device__ XPgrid_polar(){;}
	__host__ XPgrid_polar(int m, int n){allocate(m,n);}
	// Evaluates a bicubic spline at the given location
	template<enum XPgridderiv ideriv>
	__device__
	realkind BCspline_eval(int2 index,realkind2 params);
	// Allocate Host Page Locked memory for the field
	__host__
	void allocate(int m,int n);
	// Setup parameters and copy arrays to the device
	__host__
	void setup(double* spline_in,cudaMatrixr xgrid_in,cudaMatrixr ygrid_in,
					   int ii1,int jj1,realkind hx1,realkind hy1,
					   realkind hxi1,realkind hyi1,realkind xspani1,realkind yspani1);

	__host__
	void XPgrid_polarFree(void)
	{
		printf("Freeing XPgrid_polar\n");
		splinecoeff.cudaMatrixFree();
	}




};

template<typename T,const int dims>
class simple_XPgrid
{
public:
	cudaMatrixT<T> data;
	XPGridParams gridparams;
	static const int ndims = dims;
	__host__ __device__
	simple_XPgrid(){;}

	__host__
	simple_XPgrid(int n1,int n2,int n3,int n4,int n5,int n6){allocate(n1,n2,n3,n4,n5,n6);}
	__host__
	void allocate(int n1,int n2=1,int n3=1,int n4=1,int n5=1,int n6=1)
	{

		int3 allocdims;
		allocdims.x = n1;
		allocdims.y = n2;
		allocdims.z = n3*n4*n5*n6;

		gridparams.griddims[0] = n1;
		if(dims > 1)
			gridparams.griddims[1] = n2;
		if(dims > 2)
			gridparams.griddims[2] = n3;
		if(dims > 3)
			gridparams.griddims[3] = n4;
		if(dims > 4)
			gridparams.griddims[4] = n5;
		if(dims > 5)
			gridparams.griddims[5] = n6;

		cudaMatrixT<T> data_temp(allocdims.x,allocdims.y,allocdims.z);

		data = data_temp;

	}
	__host__
	void setup(double* data_in,realkind* gridspacing_in,realkind* origin_in);
	__host__
	void setupi(int* data_in,realkind* gridspacing_in,realkind* origin_in);
	__device__
	void allocate_local(void);
	// Find the cell index of a given x and y.
	__device__
	int2 findindex(realkind px,realkind py);
	// Evaluate the spline at the given location
	template<enum XPgridderiv ideriv>
	__device__
	double BCspline_eval(double px,double py);

	// Use realkind locations to fetch a location, inputs should not be normalized
	__device__
	T & operator()(realkind i1,realkind i2=0,realkind i3=0,realkind i4=0,realkind i5=0,realkind i6=0);
	__device__
	const T & operator()(realkind i1=0,realkind i2=0,realkind i3=0,realkind i4=0,realkind i5=0,realkind i6=0)const;

	__device__
	int limit_index(int index,int dim)const;

	__host__
	void copyFromDouble(double* data_in,enum cudaMemcpyKind kind);

	__host__
	void simple_XPgridFree(void)
	{printf("Freeing simple_XPgrid\n");
		data.cudaMatrixFree();
	}

private:
	enum XPgridlocation location;

};


class XPTextureGrid
{
public:
	texFunctionPtr pt2Function;
	const char* symbol;
	cudaArray* cuArray;
	XPGridParams gridparams;
	int tdims;
	int ndims;
	int my_array_reference;

	__host__ __device__
	XPTextureGrid(){texturetype = XPtex2D;allocflag=0;}

	__host__ __device__
	XPTextureGrid(int n1,int n2=0,int n3=0,int n4=0,int n5=0,int n6=0,enum XPTextureGridType textype = XPtex2D)
	{
		gridparams.griddims[0] = n1;
		gridparams.griddims[1] = n2;
		gridparams.griddims[2] = n3;
		gridparams.griddims[3] = n4;
		gridparams.griddims[4] = n5;
		gridparams.griddims[5] = n6;

		texturetype = textype;
	}

	// Use realkind locations to fetch a texel, inputs should not be normalized
	__device__
	realkind operator()(realkind i1,realkind i2,realkind i3,realkind i4,realkind i5,realkind i6);

	__host__
	void setup_dims(int* griddims_in,realkind* gridspacing_in,
								  realkind* origin_in)
	{
		for(int i=0;i<ndims+tdims;i++)
		{
			gridparams.griddims[i] = griddims_in[i];
			gridparams.gridspacing[i] = gridspacing_in[i];
			gridparams.origin[i] = origin_in[i];
		}
		return;
	}

	__host__
	void fill2D(cudaMatrixr data_in);

	__host__
	void fill2DLayered(double* data_in,enum XPgridlocation location);
	__host__
	void fill1DLayered(double* data_in,enum XPgridlocation location);

	template<enum XPgridderiv ideriv>
	__device__
	realkind deriv(realkind x1,realkind x2,realkind x3,realkind x4,realkind x5,realkind x6);

	__host__
	void XPTextureGridFree(void)
	{

		printf("Freeing XPTextureGrid\n");
		char* texrefstring = (char*)malloc(sizeof(char)*30);
		sprintf(texrefstring,"texref2D%i",my_array_reference);


		const textureReference* texRefPtr;
		CUDA_SAFE_CALL(cudaGetTextureReference(&texRefPtr, texrefstring));
		CUDA_SAFE_CALL(cudaUnbindTexture(texRefPtr));
		CUDA_SAFE_CALL(cudaFreeArray(cuArray));

	}

private:
	enum XPTextureGridType texturetype;
	unsigned int allocflag;

};

class XPCxGrid: public XPTextureGrid
{
public:
	realkind max_energy;
	// Use integer dimensions to fetch the texel
	// Use realkind locations to fetch a texel, inputs should not be normalized
	__device__
	realkind operator()(realkind i1,realkind i2,realkind i3,realkind i4,realkind i5,realkind i6);
	__host__
	void setup_cross_section(double* data_in,int* nbnsve_d,int* lbnsve_d,int* nbnsver_d,
									double* bnsves_d,realkind max_energy,int dims[4],
									int dimidx,int dimbidx,int dimbidy,int dimbidz,int ndims_in);

	enum XPTextureGridType texturetype;



	__host__
	void XPTextureGridFree(void)
	{
		printf("Freeing XPCxGrid\n");

		char* texrefstring = (char*)malloc(sizeof(char)*30);
		sprintf(texrefstring,"texref1DLayered%i",my_array_reference);


		const textureReference* texRefPtr;
		CUDA_SAFE_CALL(cudaGetTextureReference(&texRefPtr, texrefstring));
		CUDA_SAFE_CALL(cudaUnbindTexture(texRefPtr));
		CUDA_SAFE_CALL(cudaFreeArray(cuArray));

	}


};


// Object to store neutral track data
class XPtracks
{
public:
	cudaMatrixr probability;
	cudaMatrixr radius;
	cudaMatrixr height;

};


struct Cross_section_textures
{
public:

	int minz; // cxn_zmin
	int maxz; // cxn_zmax
	realkind max_energy;

	XPCxGrid cx_outside_plasma;
	XPCxGrid cx_thcx_wall;
	XPCxGrid cx_thii_wall;
	XPCxGrid cx_thcx_halo;
	XPCxGrid cx_thii_halo;
	XPCxGrid cx_thcx_beam_beam; // cxn_bbcx(cxn_zmin:cxn_zmax,nbnsvmx,cxn_zmin:cxn_zmax)
	XPCxGrid cx_thii_beam_beam;

	// Reaction Tables for Nutrav
	XPCxGrid thermal_fraction; // BNSVIIF(nbnsvmx,mj,nspecies)
	XPCxGrid electron_fraction; // BNSVIEF(nbnsvmx,mj,nspecies)
	XPCxGrid impurity_fraction; // BNSVIZF(nbnsvmx,mj,nspecies)
	XPCxGrid thermal_total; // BNSVTOT(nbnsvmx,mj,nspecies)
	XPCxGrid excitation_estimate; // BNSVEXC(nbnsvmx,mj,nspecies)

	XPCxGrid cx_fraction; // bnsvcxf(nbnsvmx,mj,nbeams,nspecies)
	XPCxGrid beam_beam_cx; // bbnsvcx(nbnsvmx,mj,nbeams,nspecies)
	XPCxGrid beam_beam_ii; // bbnsvcx(nbnsvmx,mj,nbeams,nspecies)

	// Fusion cross sections
	XPCxGrid btfus_dt; // btfus_dt(lep1,nbnsvmx)
	XPCxGrid btfus_d3; // btfus_d3(lep1,nbnsvmx)
	XPCxGrid btfus_ddn; // btfus_ddn(lep1,nbnsvmx)
	XPCxGrid btfus_ddp; // btfus_ddp(lep1,nbnsvmx)
	XPCxGrid btfus_td; // btfus_td(lep1,nbnsvmx)
	XPCxGrid btfus_tt; // btfus_tt(lep1,nbnsvmx)
	XPCxGrid btfus_3d; // btfus_3d(lep1,nbnsvmx)

	__host__
	void CX_texturesFree(void)
	{
		cx_outside_plasma.XPTextureGridFree();
		cx_thcx_wall.XPTextureGridFree();
		cx_thii_wall.XPTextureGridFree();
		cx_thcx_halo.XPTextureGridFree();
		cx_thii_halo.XPTextureGridFree();
		cx_thcx_beam_beam.XPTextureGridFree();
		cx_thii_beam_beam.XPTextureGridFree();

		// Reaction Tables for Nutrav
		thermal_fraction.XPTextureGridFree();
		electron_fraction.XPTextureGridFree();
		impurity_fraction.XPTextureGridFree();
		thermal_total.XPTextureGridFree();
		excitation_estimate.XPTextureGridFree();
		cx_fraction.XPTextureGridFree();
		beam_beam_cx.XPTextureGridFree();
		beam_beam_ii.XPTextureGridFree();
/*
		// Fusion cross sections
		btfus_dt;
		btfus_d3;
		btfus_ddn;
		btfus_ddp;
		btfus_td;
		btfus_tt;
		btfus_3d;
		*/
	}



};


class Environment
{
public:
	int nbeams; // mib = nbeam
	int nspecies; // nsbeam
	int max_species; // mibs
	int nthermal_species; // mig
	int nptcls; // per beam species
	int max_particles; // minb
	int phi_ccw; // +1 if Bphi is CCW looking down on the tokamak from above
	int zonebdyctr_shift_index; // miz
	int2 griddims; // integer spatial dimensions
	realkind2 gridspacing; // realkind spatial grid spacing

	//realkind2 ledge; // Location of outermost plasma boundary
	int ledge_transp; // transp_index of outermost plasma boundary
	int lcenter_transp;
	int ntheta_zones;
	int midplane_symetry;

	realkind xi_boundary; //ximinbnd
	realkind xi_max; //xbmbnd
	realkind theta_body0;
	realkind theta_body1;

	int ntransp_zones;// mj
	int nbeam_zones; // mimxbz = nfbzns = nthzsm(jznbmr)

	int nzones; // mj-3
	int nbeam_zones_inside; // mimxbzf = nfbznsi = nthzsm(jznbmr-nxtbzn)
	int nxi_rows; // nznbmr
	int nxi_rows_inside; // nznbmri
	int nrow_zones; // jznbmr = nznbmr+lcenter-1
	int last_inside_row; // nxtbzn

	int n_diffusion_energy_bins; // ndifbe

	int ngases; // ng

	realkind RhoSum;
	realkind average_weight_factor; // fact_wbav;

	realkind energy_factor; // fac_e

	int nr;
	int nz;
	int nint;
	int next;
	int nth;
	int nxi;
	realkind Rmin;
	realkind Rmax;
	realkind Zmin;
	realkind Zmax;

	realkind xispani;
	realkind thspani;

	realkind nbsii;
	realkind nbsjj;

	realkind fppcon;
	realkind cxpcon;
	realkind cxsplit;

	realkind delt;// length of nubeam timestep
	int istep;

	int sign_bphi;

	// Numerical Controls

	cudaMatrixr xigrid;
	cudaMatrixr thgrid;

	XPTextureSpline Psispline;
	XPTextureSpline gspline;
	XPTextureSpline Phispline;

	XPgrid_polar rspline;
	XPgrid_polar zspline;
	XPgrid_polar rsplinex;
	XPgrid_polar zsplinex;




	XPTextureGrid Bfieldr; // Coarse Bfield R-Direction
	XPTextureGrid Bfieldz; // Coarse Bfield Z-Direction
	XPTextureGrid Bfieldphi; // Coarse Bfield Phi-Direction
	XPTextureGrid transp_zone; // NGC
	XPTextureGrid beam_zone; // NGC2
	XPTextureGrid Xi_map;
	XPTextureGrid Theta_map;
	XPTextureGrid rotation; // omegag(mj), plasma_rotation(nR,nZ)
	XPTextureGrid limiter_map; // map of distance to nearest limiter point
	XPTextureGrid Ymidplane; // ympx(mtbl)

	simple_XPgrid<realkind,1> Xi_bloated;// xiblo(lcenter+xi_boundary*nzones+1)
	simple_XPgrid<int,1> ntheta_row_zones;//nthzsm

	Cross_section_textures cx_cross_sections;


	simple_XPgrid<realkind,3> background_density; // background_density rhob(mj,mig,miz)
	simple_XPgrid<realkind,2> omega_wall_neutrals; //OWALL0(mig,mj)
	simple_XPgrid<realkind,2> omega_thermal_neutrals; //ovol02(mig,mimxbz)
	simple_XPgrid<realkind,2> beamcx_neutral_density; // bn0x2p(mimxbz,mibs)
	simple_XPgrid<realkind,2> beamcx_neutral_velocity; // bv0x2p(mimxbz,mibs)
	simple_XPgrid<realkind,2> beamcx_neutral_energy; // be0x2p(mimxbz,mibs)
	simple_XPgrid<realkind,2> species_atomic_number; // xzbeams(nspecies)
	simple_XPgrid<realkind,1> grid_zone_volume; // bmvol(mimxbz)
	simple_XPgrid<realkind,4> beam_1stgen_neutral_density2d; // bn002(mib, 3, 2, mimxbzf)

	simple_XPgrid<realkind,1> injection_rate; // xninja(mib)

	simple_XPgrid<realkind,2> beam_ion_initial_velocity; // viona(3,mib)
	simple_XPgrid<realkind,4> beam_ion_velocity_direction; //vcxbn0(mib,3,2,mimxbzf)
	//although beam_ion_velocity_direction, needs to be changed to rzphi coordinates
	simple_XPgrid<realkind,2> toroidal_beam_velocity; // vbtr2p(mimxbz,mibs)

	simple_XPgrid<realkind,2> average_beam_weight; // wbav(mj,mibs)

	simple_XPgrid<int,1> is_fusion_product;// nlfprod(mibs)

	// Fokker Planck Collision Stuff

	simple_XPgrid<realkind,2> electron_temperature; // TE(mj,miz)
	simple_XPgrid<realkind,2> ion_temperature; // TI(mj,miz);
	simple_XPgrid<realkind,1> injection_energy; // einjs(mibs)
	simple_XPgrid<realkind,3> FPcoeff_arrayC; // cfa(mj,mibs,4)
	simple_XPgrid<realkind,3> FPcoeff_arrayD; // dfa(mj,mibs,4)
	simple_XPgrid<realkind,3> FPcoeff_arrayE; // efa(mj,mibs,4)

	simple_XPgrid<realkind,1> loop_voltage; // vpoh(mj)
	simple_XPgrid<realkind,1> current_shielding; // xjbfac(mj)
	simple_XPgrid<realkind,2> thermal_velocity; // vmin(mj,mibs)

	XPTextureGrid fusion_anomalous_radialv; // velb_fi(mj) -> mapped to r,z
	XPTextureGrid fusion_anomalous_diffusion; // difb_fi(mj) -> mapped to r,z
	XPTextureGrid beam_anomalous_radialv; // velb_bi(mj) -> mapped to r,z
	XPTextureGrid beam_anomalous_diffusion; // difb_bi(mj) -> mapped to r,z

	simple_XPgrid<realkind,1> adif_multiplier; // fdifbe(ndifbe)
	simple_XPgrid<realkind,1> adif_energies; // edifbe(ndifbe)

	XPTextureGrid dxi_spacing1; // dxi(mj) iz = 1 -> mapped to r,z
	XPTextureGrid dxi_spacing2; // dxi(mj) iz = 2 -> mapped to r,z


	__host__ __device__
	Environment(){;}


	__host__
	void allocate_Grids(void);

	__host__
	void setupBfield(void);

	__device__
	void polarintrp(realkind rin,realkind thin,realkind2* params_in,int2* index_in);

	__host__
	cudaMatrixr mapTransp_data_to_RZ(double* data_in_h,int ndim3=1,int bloated=0);

	__host__
	void setup_transp_zones(void);

	__host__
	void setup_parameters(int* intparams,double* dbleparams);

	__host__
	void setup_fields(double** data_in,int** idata_in);

	__host__
	void setup_cross_sections(int* nbnsve,int* lbnsve,int* nbnsver,
			double* bnsves,
			double* bnsvtot,double* bnsvexc,
			double* bnsviif,double* bnsvief,double* bnsvizf,
			double* bnsvcxf,double* bbnsvcx,double* bbnsvii,
			double* cxn_thcx_a,double* cxn_thcx_wa,double* cxn_thii_wa,
			double* cxn_thcx_ha,double* cxn_thii_ha,double* cxn_bbcx,
			double* cxn_bbii,double* btfus_dt,double* btfus_d3,
			double* btfus_ddn,double* btfus_ddp,double* btfus_td,
			double* btfus_tt,double* btfus_3d);

	__device__
	realkind3 Bvector(realkind Rmajor,realkind dPsidR,realkind dPsidZ,realkind g);

	__device__
	realkind3 eval_Bvector(realkind r,realkind z);

	__host__
	void check_environment(void);

	__host__
	void EnvironmentFree(void)
	{
		xigrid.cudaMatrixFree();
		thgrid.cudaMatrixFree();

		Psispline.XPTextureSplineFree();
		gspline.XPTextureSplineFree();
		Phispline.XPTextureSplineFree();

		rspline.XPgrid_polarFree();
		zspline.XPgrid_polarFree();
		rsplinex.XPgrid_polarFree();
		zsplinex.XPgrid_polarFree();

		Bfieldr.XPTextureGridFree();
		Bfieldz.XPTextureGridFree();
		Bfieldphi.XPTextureGridFree();
		transp_zone.XPTextureGridFree();
		beam_zone.XPTextureGridFree();
		Xi_map.XPTextureGridFree();
		Theta_map.XPTextureGridFree();
		rotation.XPTextureGridFree();
		limiter_map.XPTextureGridFree();
		Ymidplane.XPTextureGridFree();

		fusion_anomalous_radialv.XPTextureGridFree();
		fusion_anomalous_diffusion.XPTextureGridFree();
		beam_anomalous_radialv.XPTextureGridFree();
		beam_anomalous_diffusion.XPTextureGridFree();

		dxi_spacing1.XPTextureGridFree();
		dxi_spacing2.XPTextureGridFree();


		Xi_bloated.simple_XPgridFree();
		ntheta_row_zones.simple_XPgridFree();

		background_density.simple_XPgridFree();
		omega_wall_neutrals.simple_XPgridFree();
		omega_thermal_neutrals.simple_XPgridFree();
		beamcx_neutral_density.simple_XPgridFree();
		beamcx_neutral_velocity.simple_XPgridFree();
		beamcx_neutral_energy.simple_XPgridFree();
		species_atomic_number.simple_XPgridFree();
		grid_zone_volume.simple_XPgridFree();
		beam_1stgen_neutral_density2d.simple_XPgridFree();

		injection_rate.simple_XPgridFree();

		beam_ion_initial_velocity.simple_XPgridFree();
		beam_ion_velocity_direction.simple_XPgridFree();

		toroidal_beam_velocity.simple_XPgridFree();
		average_beam_weight.simple_XPgridFree();

		is_fusion_product.simple_XPgridFree();

		electron_temperature.simple_XPgridFree();
		ion_temperature.simple_XPgridFree();
		injection_energy.simple_XPgridFree();
		FPcoeff_arrayC.simple_XPgridFree();
		FPcoeff_arrayD.simple_XPgridFree();
		FPcoeff_arrayE.simple_XPgridFree();

		loop_voltage.simple_XPgridFree();
		current_shielding.simple_XPgridFree();
		thermal_velocity.simple_XPgridFree();

		adif_multiplier.simple_XPgridFree();
		adif_energies.simple_XPgridFree();

		cx_cross_sections.CX_texturesFree();

		// Reset texture reference counters
		next_tex2D = 0;
		next_tex1DLayered = 0;
		next_tex2DLayered = 0;



	}



};

extern Environment plasma_h;
Environment plasma_h;



__device__
realkind3 Environment::Bvector(realkind Rmajor,realkind dPsidR,realkind dPsidZ,realkind g)
{
	realkind3 result;
	result.x = (bphi_sign*dPsidZ)/Rmajor;
	result.y = (bphi_sign*(-1.0)*dPsidR)/Rmajor;
	result.z = g/(pow(Rmajor,2));

	return result;
}

__device__
realkind3 Environment::eval_Bvector(realkind r,realkind z)
{

	realkind dPsidR = Psispline.BCspline_eval<XPgridderiv_dfdx>(r,z);
	realkind dPsidZ = Psispline.BCspline_eval<XPgridderiv_dfdy>(r,z);
	realkind g = gspline.BCspline_eval<XPgridderiv_f>(r,z);

	realkind3 result;

	result = Bvector(r,dPsidR,dPsidZ,g);

	return result;


}





__global__
void setupBfield_kernel(Environment* plasma,int nr,int nz,realkind2 origin,
										 cudaMatrixr Bfieldr_temp,cudaMatrixr Bfieldz_temp,cudaMatrixr Bfieldphi_temp)
{
	unsigned int idx = threadIdx.x;
	unsigned int idy = threadIdx.y;
	unsigned int gidx = blockIdx.x*blockDim.x+idx;
	unsigned int gidy = blockIdx.y*blockDim.y+idy;
	unsigned int tid = idx+blockDim.x*idy;

	realkind pr = gidx*(plasma->Psispline.gridspacing.x)+(origin.x);
	realkind pz = gidy*(plasma->Psispline.gridspacing.y)+(origin.y);

	__shared__ realkind3 Bvector[256];

	if((gidx < nr)&&(gidy < nz))
	{
		Bvector[tid] = plasma->eval_Bvector(pr,pz);
	}

	__syncthreads();

	if((gidx < nr)&&(gidy < nz))
	{


		Bfieldr_temp(gidx,gidy) = Bvector[tid].x*1.0e-4;
		Bfieldz_temp(gidx,gidy) = Bvector[tid].y*1.0e-4;
		Bfieldphi_temp(gidx,gidy) = Bvector[tid].z*1.0e-4;
	}

}



__host__
void Environment::setupBfield(void)
{
	dim3 cudaGridSize((16+nr-1)/16,(16+nz-1)/16,1);
	dim3 cudaBlockSize(16,16,1);


	printf("setting up bfield \n");

	cudaMatrixr Bfieldr_temp(nr,nz);
	cudaMatrixr Bfieldz_temp(nr,nz);
	cudaMatrixr Bfieldphi_temp(nr,nz);

	int griddims[2] = {nr,nz};
	realkind gridspacing1[2];
	realkind origin[2] = {Rmin,Zmin};
	realkind2 origin_d;
	gridspacing1[0] = gridspacing.x;
	gridspacing1[1] = gridspacing.y;

	origin_d.x = origin[0];
	origin_d.y = origin[1];

	Bfieldr.tdims = 2;
	Bfieldz.tdims = 2;
	Bfieldphi.tdims = 2;
	Bfieldr.ndims = 0;
	Bfieldz.ndims = 0;
	Bfieldphi.ndims = 0;

	Bfieldr.setup_dims(griddims,gridspacing1,origin);
	Bfieldz.setup_dims(griddims,gridspacing1,origin);
	Bfieldphi.setup_dims(griddims,gridspacing1,origin);

	Environment* plasma_out;
	CUDA_SAFE_CALL(cudaMalloc((void**)&plasma_out,sizeof(Environment)));

	plasma_h = *this;

	CUDA_SAFE_CALL(cudaMemcpy(plasma_out,&plasma_h,sizeof(Environment),cudaMemcpyHostToDevice));





	CUDA_SAFE_KERNEL((setupBfield_kernel<<<cudaGridSize,cudaBlockSize>>>(
									plasma_out,nr,nz,origin_d,Bfieldr_temp,Bfieldz_temp,Bfieldphi_temp)));



	cudaDeviceSynchronize();

	Bfieldr.fill2D(Bfieldr_temp);
	Bfieldz.fill2D(Bfieldz_temp);
	Bfieldphi.fill2D(Bfieldphi_temp);



}


__host__
 void XPTextureSpline::allocate(int2 griddims_in,enum XPgridlocation location)
{
	griddims = griddims_in;

	printf(" nelements in XPgrid::setup = %i \n",griddims.x*griddims.y);

	//CUDA_SAFE_KERNEL(cudaMallocPitch((void**)&spline,&pitch,(griddims.x+8)*sizeof(BCspline),(griddims.y+8)));
	//CUDA_SAFE_KERNEL(cudaMalloc((void**)&spline,(griddims.x*griddims.y)*sizeof(BCspline)));

}


__device__
void XPTextureSpline::allocate_local(BCspline* spline_local)
{
	// This function sets up a 4x4 spline array in shared memory on the gpu.
	if(threadIdx.x == 0)
	{
		griddims.x = 16;
		griddims.y = 16;
		pitch = 16*sizeof(BCspline);
	}
	__syncthreads();

	return;

}

__device__
int2 XPTextureSpline::findindex(realkind px,realkind py)
{
	int2 result;
	result.x = max(0,min((griddims.x-2),((int)(floor((px-origin.x)/gridspacing.x)))));
	result.y = max(0,min((griddims.y-2),((int)(floor((py-origin.y)/gridspacing.y)))));

	return result;
}

// This is going to be a template function to improve performance
template<enum XPgridderiv ideriv>
__device__
realkind XPTextureSpline::BCspline_eval(realkind px,realkind py)
{
	realkind sum  = 0.0;
	realkind xp;
	realkind xpi;
	realkind yp;
	realkind ypi;
	realkind xp2;
	realkind xpi2;
	realkind yp2;
	realkind ypi2;
	realkind cx;
	realkind cxi;
	realkind hx2;
	realkind cy;
	realkind cyi;
	realkind hy2;
	realkind cxd;
	realkind cxdi;
	realkind cyd;
	realkind cydi;
	realkind sixth = 0.166666666666666667;
	int2 index;
	unsigned int i;
	unsigned int j;


	px = fmax((origin.x),fmin(px,(origin.x+gridspacing.x*((realkind)(griddims.x)))));
	py = fmax((origin.y),fmin(py,(origin.y+gridspacing.y*((realkind)(griddims.y)))));




	index = findindex(px,py);


	i = index.x;
	j = index.y;

	realkind hxi = 1.0/gridspacing.x;
	realkind hyi = 1.0/gridspacing.y;

	realkind hx = gridspacing.x;
	realkind hy = gridspacing.y;

	xp = (px-origin.x)/gridspacing.x;
	yp = (py-origin.y)/gridspacing.y;

	xp = (xp-((realkind)index.x));
	yp = (yp-((realkind)index.y));

	xpi=1.0-xp;
	xp2=xp*xp;
	xpi2=xpi*xpi;

	cx=xp*(xp2-1.0);
	cxi=xpi*(xpi2-1.0);
	cxd = 3.0*xp2-1.0;
	cxdi= -3.0*xpi2+1.0;
	hx2=hx*hx;

	ypi=1.0-yp;
	yp2=yp*yp;
	ypi2=ypi*ypi;

	cy=yp*(yp2-1.0);
	cyi=ypi*(ypi2-1.0);
	cyd = 3.0*yp2-1.0;
	cydi= -3.0*ypi2+1.0;
	hy2=hy*hy;

	//printf("xp = %f, yp = %f \n", xp,yp);

	switch(ideriv)
	{
	case XPgridderiv_f:

		sum = xpi*(ypi*get_spline(i,j,0)+yp*get_spline(i,j+1,0))+
				   xp*(ypi*get_spline(i+1,j,0)+yp*get_spline(i+1,j+1,0));

		sum += sixth*hx2*(cxi*(ypi*get_spline(i,j,1)+yp*get_spline(i,j+1,1))+
					 cx*(ypi*get_spline(i+1,j,1)+yp*get_spline(i+1,j+1,1)));

		sum += sixth*hy2*(xpi*(cyi*get_spline(i,j,2)+cy*get_spline(i,j+1,2))+
					 xp*(cyi*get_spline(i+1,j,2)+cy*get_spline(i+1,j+1,2)));

		sum += sixth*sixth*hx2*hy2*(cxi*(cyi*get_spline(i,j,3)+cy*get_spline(i,j+1,3))+
					 cx*(cyi*get_spline(i+1,j,3)+cy*get_spline(i+1,j+1,3)));

		break;
	case XPgridderiv_dfdx:

		sum = hxi*(-1.0*(ypi*get_spline(i,j,0)+yp*get_spline(i,j+1,0))+
					(ypi*get_spline(i+1,j,0)+yp*get_spline(i+1,j+1,0)));

		sum += sixth*hx*(cxdi*(ypi*get_spline(i,j,1)+yp*get_spline(i,j+1,1))+
						cxd*(ypi*get_spline(i+1,j,1)+yp*get_spline(i+1,j+1,1)));

		sum += sixth*hxi*hy2*(-1.0*(cyi*get_spline(i,j,2)+cy*get_spline(i,j+1,2))+
					(cyi*get_spline(i+1,j,2)+cy*get_spline(i+1,j+1,2)));

		sum += sixth*sixth*hx*hy2*(cxdi*(cyi*get_spline(i,j,3)+cy*get_spline(i,j+1,3))+
					cxd*(cyi*get_spline(i+1,j,3)+cy*get_spline(i+1,j+1,3)));

		break;
	case XPgridderiv_dfdy:
        sum = hyi*(xpi*(-1.0*get_spline(i,j,0)+get_spline(i,j+1,0))+
        			xp*(-1.0*get_spline(i+1,j,0)+get_spline(i+1,j+1,0)));

        sum += sixth*hx2*hyi*(cxi*(-1.0*get_spline(i,j,1)+get_spline(i,j+1,1))+
            cx*(-1.0*get_spline(i+1,j,1)+get_spline(i+1,j+1,1)));

        sum += sixth*hy*(xpi*(cydi*get_spline(i,j,2)+cyd*get_spline(i,j+1,2))+
            xp*(cydi*get_spline(i+1,j,2)+cyd*get_spline(i+1,j+1,2)));

        sum += sixth*sixth*hx2*hy*(cxi*(cydi*get_spline(i,j,3)+cyd*get_spline(i,j+1,3))+
            cx*(cydi*get_spline(i+1,j,3)+cyd*get_spline(i+1,j+1,3)));

        break;
	case XPgridderiv_dfdxx:
        sum = (xpi*(ypi*get_spline(i,j,1)+yp*get_spline(i,j+1,1))+
            xp*(ypi*get_spline(i+1,j,1)+yp*get_spline(i+1,j+1,1)));

        sum += sixth*hy2*(
            xpi*(cyi*get_spline(i,j,3)+cy*get_spline(i,j+1,3))+
            xp*(cyi*get_spline(i+1,j,3)+cy*get_spline(i+1,j+1,3)));

        break;
	case XPgridderiv_dfdyy:
        sum=(xpi*(ypi*get_spline(i,j,2)+yp*get_spline(i,j+1,2))+
            xp*(ypi*get_spline(i+1,j,2)+yp*get_spline(i+1,j+1,2)));

        sum += sixth*hx2*(cxi*(ypi*get_spline(i,j,3)+yp*get_spline(i,j+1,3))+
            cx*(ypi*get_spline(i+1,j,3)+yp*get_spline(i+1,j+1,3)));

        break;
	case XPgridderiv_dfdxy:

        sum=hxi*hyi*(get_spline(i,j,0)-get_spline(i,j+1,0)-
        		get_spline(i+1,j,0)+get_spline(i+1,j+1,0));

        sum += sixth*hx*hyi*(cxdi*(-1.0*get_spline(i,j,1)+get_spline(i,j+1,1))+
            cxd*(-get_spline(i+1,j,1)+get_spline(i+1,j+1,1)));

        sum += sixth*hxi*hy*(-(cydi*get_spline(i,j,2)+cyd*get_spline(i,j+1,2))
            +(cydi*get_spline(i+1,j,2)+cyd*get_spline(i+1,j+1,2)));

        sum += sixth*sixth*hx*hy*(cxdi*(cydi*get_spline(i,j,2)+cyd*get_spline(i,j+1,2))+
            cxd*(cydi*get_spline(i+1,j,2)+cyd*get_spline(i+1,j+1,2)));

        break;
	default:
		break;
	}

	return sum;

}

__device__
void XPTextureSpline::shift_local(XPTextureSpline grid_in,int nx,int ny)
{

	unsigned int idx = threadIdx.x;
	unsigned int idy = threadIdx.y;
	unsigned int gidx = blockIdx.x*blockDim.x+idx;
	unsigned int gidy = blockIdx.y*blockDim.y+idy;

	realkind pr = gidx*grid_in.gridspacing.x+grid_in.origin.x;
	realkind pz = gidy*grid_in.gridspacing.y+grid_in.origin.y;

	if(idx == 0)
	{
		gridspacing = grid_in.gridspacing;
		origin.x = pr;
		origin.y = pz;
	}
	__syncthreads();

	if((gidx < nx)&&(gidy < ny))
	{
		spline[idx+(blockDim.x+1)*idy] = grid_in.spline[gidx+grid_in.griddims.x*gidy];
		if(idx == (blockDim.x-1))
		{
			spline[idx+1+(blockDim.x+1)*idy] = grid_in.spline[gidx+1+grid_in.griddims.x*gidy];
		}
		if(idy == (blockDim.y+1))
		{
			spline[idx+(blockDim.x+1)*(idy+1)] = grid_in.spline[gidx+grid_in.griddims.x*(gidy+1)];
		}
	}
	__syncthreads();

}


__global__
void XPTextureSpline_setup_kernel(cudaMatrixr grid_out,cudaMatrixd spline_in,size_t spline_pitch,int nr,int nz)
{
	unsigned int idx = threadIdx.x;
	unsigned int gidx = threadIdx.x+blockDim.x*blockIdx.x;
	unsigned int idy = threadIdx.y;
	unsigned int gidy = idy + blockDim.y*blockIdx.y;

	__shared__ BCspline sdata[256];

	if((gidx<nr)&&(gidy<nz))
	{
		sdata[idx+16*idy][0] = spline_in(0,gidx,gidy);
		sdata[idx+16*idy][1] = spline_in(1,gidx,gidy);
		sdata[idx+16*idy][2] = spline_in(2,gidx,gidy);
		sdata[idx+16*idy][3] = spline_in(3,gidx,gidy);

	}
	__syncthreads();
	if((gidx<nr)&&(gidy<nz))
	{

		grid_out(gidx,gidy,0) = sdata[idx+16*idy][0];
		grid_out(gidx,gidy,1) = sdata[idx+16*idy][1];
		grid_out(gidx,gidy,2) = sdata[idx+16*idy][2];
		grid_out(gidx,gidy,3) = sdata[idx+16*idy][3];

	}




}



__host__
void XPTextureSpline::setup(double* spline_in,realkind xmin,realkind xmax,realkind ymin,realkind ymax)
{
	size_t temp_pitch;

	origin.x = xmin;
	origin.y = ymin;

	dim3 cudaBlockSize(16,16,1);
	dim3 cudaGridSize((griddims.x+16-1)/16,(griddims.y+16-1)/16,1);

	cudaMatrixd spline_temp(4,griddims.x,griddims.y);

	cudaMatrixr data_out_temp(griddims.x,griddims.y,4);


	spline_temp.cudaMatrixcpy(spline_in,cudaMemcpyHostToDevice);

	CUDA_SAFE_KERNEL((XPTextureSpline_setup_kernel<<<cudaGridSize,cudaBlockSize>>>
			(data_out_temp,spline_temp,pitch,griddims.x,griddims.y)));

	fill2DLayered(data_out_temp);

	spline_temp.cudaMatrixFree();
	data_out_temp.cudaMatrixFree();


}

__host__
void XPTextureSpline::fill2DLayered(cudaMatrixr data_in)
{

	int nx = 1;
	int ny = 1;

	char* texrefstring = (char*)malloc(sizeof(char)*30);
	char* texfetchstring = (char*)malloc(sizeof(char)*30);

	int itemp = next_tex2DLayered;
	next_tex2DLayered++;

	sprintf(texrefstring,"texref2DLayered%i",itemp);
	sprintf(texfetchstring,"fetchtexref2DLayeredPtr%i",itemp);
	my_array_reference = itemp;

	symbol = texrefstring;

	CUDA_SAFE_CALL(cudaMemcpyFromSymbol(&pt2Function,texfetchstring,sizeof(texFunctionPtr)));

	nx = griddims.x;
	ny = griddims.y;

	printf(" fill2DLayered nx = %i, ny = %i \n", nx,ny);

	cudaExtent extent = make_cudaExtent(nx,ny,4);

	cudaMemcpy3DParms params = {0};
	params.kind = cudaMemcpyDeviceToDevice;

	params.kind = cudaMemcpyDeviceToDevice;
#ifdef __double_precision
	cudaChannelFormatDesc desc = cudaCreateChannelDesc(32,32,0,0,cudaChannelFormatKindSigned);
#else
	cudaChannelFormatDesc desc = cudaCreateChannelDesc<realkind>();
#endif

	CUDA_SAFE_CALL(cudaMalloc3DArray(&cuArray,&desc,extent,cudaArrayLayered));

	params.srcPtr = data_in.getptr();
	params.dstArray = cuArray;
	params.extent = make_cudaExtent(nx,ny,4);

	cudaDeviceSynchronize();
	CUDA_SAFE_CALL(cudaMemcpy3D(&params));

	cudaDeviceSynchronize();
	const textureReference* texRefPtr;
	CUDA_SAFE_CALL(cudaGetTextureReference(&texRefPtr, symbol));
	cudaChannelFormatDesc channelDesc;
	CUDA_SAFE_CALL(cudaGetChannelDesc(&channelDesc, cuArray));
	CUDA_SAFE_KERNEL(cudaBindTextureToArray(texRefPtr, cuArray, &channelDesc));


}


__host__
 void XPgrid::allocate(int2 griddims_in,enum XPgridlocation location)
{
	griddims = griddims_in;

	printf(" nelements in XPgrid::setup = %i \n",griddims.x*griddims.y);

	spline = NULL;

	//CUDA_SAFE_KERNEL(cudaMallocPitch((void**)&spline,&pitch,(griddims.x+8)*sizeof(BCspline),(griddims.y+8)));
	CUDA_SAFE_KERNEL(cudaMalloc((void**)&spline,(griddims.x*griddims.y)*sizeof(BCspline)));

}


__device__
void XPgrid::allocate_local(BCspline* spline_local)
{
	// This function sets up a 4x4 spline array in shared memory on the gpu.
	if(threadIdx.x == 0)
	{
		spline = spline_local;
		griddims.x = 16;
		griddims.y = 16;
		pitch = 16*sizeof(BCspline);
	}
	__syncthreads();

	return;

}

__device__
int2 XPgrid::findindex(realkind px,realkind py)
{
	int2 result;
	result.x = (int)(floor((px-origin.x)/gridspacing.x));
	result.y = (int)(floor((py-origin.y)/gridspacing.y));

	return result;
}

// This is going to be a template function to improve performance
template<enum XPgridderiv ideriv>
__device__
realkind XPgrid::BCspline_eval(realkind px,realkind py)
{
	realkind sum  = 0.0;
	realkind xp;
	realkind xpi;
	realkind yp;
	realkind ypi;
	realkind xp2;
	realkind xpi2;
	realkind yp2;
	realkind ypi2;
	realkind cx;
	realkind cxi;
	realkind hx2;
	realkind cy;
	realkind cyi;
	realkind hy2;
	realkind cxd;
	realkind cxdi;
	realkind cyd;
	realkind cydi;
	realkind sixth = 0.166666666666666667;
	int2 index;
	unsigned int i;
	unsigned int j;


	index = findindex(px,py);


	i = index.x;
	j = index.y;

	realkind hxi = 1.0/gridspacing.x;
	realkind hyi = 1.0/gridspacing.y;

	realkind hx = gridspacing.x;
	realkind hy = gridspacing.y;

	xp = (px-origin.x)/gridspacing.x;
	yp = (py-origin.y)/gridspacing.y;

	xp = (xp-((realkind)index.x));
	yp = (yp-((realkind)index.y));

	xpi=1.0-xp;
	xp2=xp*xp;
	xpi2=xpi*xpi;

	cx=xp*(xp2-1.0);
	cxi=xpi*(xpi2-1.0);
	cxd = 3.0*xp2-1.0;
	cxdi= -3.0*xpi2+1.0;
	hx2=hx*hx;

	ypi=1.0-yp;
	yp2=yp*yp;
	ypi2=ypi*ypi;

	cy=yp*(yp2-1.0);
	cyi=ypi*(ypi2-1.0);
	cyd = 3.0*yp2-1.0;
	cydi= -3.0*ypi2+1.0;
	hy2=hy*hy;

	//printf("xp = %f, yp = %f \n", xp,yp);

	switch(ideriv)
	{
	case XPgridderiv_f:

		sum = xpi*(ypi*get_spline(i,j)[0]+yp*get_spline(i,j+1)[0])+
				   xp*(ypi*get_spline(i+1,j)[0]+yp*get_spline(i+1,j+1)[0]);

		sum += sixth*hx2*(cxi*(ypi*get_spline(i,j)[1]+yp*get_spline(i,j+1)[1])+
					 cx*(ypi*get_spline(i+1,j)[1]+yp*get_spline(i+1,j+1)[1]));

		sum += sixth*hy2*(xpi*(cyi*get_spline(i,j)[2]+cy*get_spline(i,j+1)[2])+
					 xp*(cyi*get_spline(i+1,j)[2]+cy*get_spline(i+1,j+1)[2]));

		sum += sixth*sixth*hx2*hy2*(cxi*(cyi*get_spline(i,j)[3]+cy*get_spline(i,j+1)[3])+
					 cx*(cyi*get_spline(i+1,j)[3]+cy*get_spline(i+1,j+1)[3]));

		break;
	case XPgridderiv_dfdx:

		sum = hxi*(-1.0*(ypi*get_spline(i,j)[0]+yp*get_spline(i,j+1)[0])+
					(ypi*get_spline(i+1,j)[0]+yp*get_spline(i+1,j+1)[0]));

		sum += sixth*hx*(cxdi*(ypi*get_spline(i,j)[1]+yp*get_spline(i,j+1)[1])+
						cxd*(ypi*get_spline(i+1,j)[1]+yp*get_spline(i+1,j+1)[1]));

		sum += sixth*hxi*hy2*(-1.0*(cyi*get_spline(i,j)[2]+cy*get_spline(i,j+1)[2])+
					(cyi*get_spline(i+1,j)[2]+cy*get_spline(i+1,j+1)[2]));

		sum += sixth*sixth*hx*hy2*(cxdi*(cyi*get_spline(i,j)[3]+cy*get_spline(i,j+1)[3])+
					cxd*(cyi*get_spline(i+1,j)[3]+cy*get_spline(i+1,j+1)[3]));

		break;
	case XPgridderiv_dfdy:
        sum = hyi*(xpi*(-1.0*get_spline(i,j)[0]+get_spline(i,j+1)[0])+
        			xp*(-1.0*get_spline(i+1,j)[0]+get_spline(i+1,j+1)[0]));

        sum += sixth*hx2*hyi*(cxi*(-1.0*get_spline(i,j)[1]+get_spline(i,j+1)[1])+
            cx*(-1.0*get_spline(i+1,j)[1]+get_spline(i+1,j+1)[1]));

        sum += sixth*hy*(xpi*(cydi*get_spline(i,j)[2]+cyd*get_spline(i,j+1)[2])+
            xp*(cydi*get_spline(i+1,j)[2]+cyd*get_spline(i+1,j+1)[2]));

        sum += sixth*sixth*hx2*hy*(cxi*(cydi*get_spline(i,j)[3]+cyd*get_spline(i,j+1)[3])+
            cx*(cydi*get_spline(i+1,j)[3]+cyd*get_spline(i+1,j+1)[3]));

        break;
	case XPgridderiv_dfdxx:
        sum = (xpi*(ypi*get_spline(i,j)[1]+yp*get_spline(i,j+1)[1])+
            xp*(ypi*get_spline(i+1,j)[1]+yp*get_spline(i+1,j+1)[1]));

        sum += sixth*hy2*(
            xpi*(cyi*get_spline(i,j)[3]+cy*get_spline(i,j+1)[3])+
            xp*(cyi*get_spline(i+1,j)[3]+cy*get_spline(i+1,j+1)[3]));

        break;
	case XPgridderiv_dfdyy:
        sum=(xpi*(ypi*get_spline(i,j)[2]+yp*get_spline(i,j+1)[2])+
            xp*(ypi*get_spline(i+1,j)[2]+yp*get_spline(i+1,j+1)[2]));

        sum += sixth*hx2*(cxi*(ypi*get_spline(i,j)[3]+yp*get_spline(i,j+1)[3])+
            cx*(ypi*get_spline(i+1,j)[3]+yp*get_spline(i+1,j+1)[3]));

        break;
	case XPgridderiv_dfdxy:

        sum=hxi*hyi*(get_spline(i,j)[0]-get_spline(i,j+1)[0]-
        		get_spline(i+1,j)[0]+get_spline(i+1,j+1)[0]);

        sum += sixth*hx*hyi*(cxdi*(-1.0*get_spline(i,j)[1]+get_spline(i,j+1)[1])+
            cxd*(-get_spline(i+1,j)[1]+get_spline(i+1,j+1)[1]));

        sum += sixth*hxi*hy*(-(cydi*get_spline(i,j)[2]+cyd*get_spline(i,j+1)[2])
            +(cydi*get_spline(i+1,j)[2]+cyd*get_spline(i+1,j+1)[2]));

        sum += sixth*sixth*hx*hy*(cxdi*(cydi*get_spline(i,j)[2]+cyd*get_spline(i,j+1)[2])+
            cxd*(cydi*get_spline(i+1,j)[2]+cyd*get_spline(i+1,j+1)[2]));

        break;
	default:
		break;
	}

	return sum;

}

__device__
void XPgrid::shift_local(XPgrid grid_in,int nx,int ny)
{

	unsigned int idx = threadIdx.x;
	unsigned int idy = threadIdx.y;
	unsigned int gidx = blockIdx.x*blockDim.x+idx;
	unsigned int gidy = blockIdx.y*blockDim.y+idy;

	realkind pr = gidx*grid_in.gridspacing.x+grid_in.origin.x;
	realkind pz = gidy*grid_in.gridspacing.y+grid_in.origin.y;

	if(idx == 0)
	{
		gridspacing = grid_in.gridspacing;
		origin.x = pr;
		origin.y = pz;
	}
	__syncthreads();

	if((gidx < nx)&&(gidy < ny))
	{
		spline[idx+(blockDim.x+1)*idy] = grid_in.spline[gidx+grid_in.griddims.x*gidy];
		if(idx == (blockDim.x-1))
		{
			spline[idx+1+(blockDim.x+1)*idy] = grid_in.spline[gidx+1+grid_in.griddims.x*gidy];
		}
		if(idy == (blockDim.y+1))
		{
			spline[idx+(blockDim.x+1)*(idy+1)] = grid_in.spline[gidx+grid_in.griddims.x*(gidy+1)];
		}
	}
	__syncthreads();

}


__global__
void XPgrid_setup_kernel(XPgrid grid_out,cudaMatrixd spline_in,size_t spline_pitch,int nr,int nz)
{
	unsigned int idx = threadIdx.x;
	unsigned int gidx = threadIdx.x+blockDim.x*blockIdx.x;
	unsigned int idy = threadIdx.y;
	unsigned int gidy = idy + blockDim.y*blockIdx.y;

	__shared__ BCspline sdata[256];

	if((gidx<nr)&&(gidy<nz))
	{
		sdata[idx+16*idy][0] = spline_in(0,gidx,gidy);
		sdata[idx+16*idy][1] = spline_in(1,gidx,gidy);
		sdata[idx+16*idy][2] = spline_in(2,gidx,gidy);
		sdata[idx+16*idy][3] = spline_in(3,gidx,gidy);

	}
	__syncthreads();
	if((gidx<nr)&&(gidy<nz))
	{

		grid_out.get_spline(gidx,gidy) = sdata[idx+16*idy];

	}




}



__host__
void XPgrid::setup(double* spline_in,realkind xmin,realkind xmax,realkind ymin,realkind ymax)
{
	size_t temp_pitch;

	origin.x = xmin;
	origin.y = ymin;

	dim3 cudaBlockSize(16,16,1);
	dim3 cudaGridSize((griddims.x+16-1)/16,(griddims.y+16-1)/16,1);

	cudaMatrixd spline_temp(4,griddims.x,griddims.y);


	spline_temp.cudaMatrixcpy(spline_in,cudaMemcpyHostToDevice);

	CUDA_SAFE_KERNEL((XPgrid_setup_kernel<<<cudaGridSize,cudaBlockSize>>>
			(*this,spline_temp,pitch,griddims.x,griddims.y)));

	spline_temp.cudaMatrixFree();


}


template<typename T,int dims>
__host__
void simple_XPgrid<T,dims>::setup(double* data_in,realkind* gridspacing_in,realkind* origin_in)
{
	for(int i=0;i<dims;i++)
	{
		gridparams.gridspacing[i] = gridspacing_in[i];
		gridparams.origin[i] = origin_in[i];
	}

	copyFromDouble(data_in,cudaMemcpyHostToDevice);
}

template<typename T,int dims>
__host__
void simple_XPgrid<T,dims>::setupi(int* data_in,realkind* gridspacing_in,realkind* origin_in)
{
	for(int i=0;i<dims;i++)
	{
		gridparams.gridspacing[i] = gridspacing_in[i];
		gridparams.origin[i] = origin_in[i];
	}

	CUDA_SAFE_KERNEL(data.cudaMatrixcpyHostToDevice(data_in));
}



template<enum XPgridderiv ideriv>
__device__
realkind XPTextureGrid::deriv(realkind x1,realkind x2=0,realkind x3=0,realkind x4=0,realkind x5=0,realkind x6=0)
{
	realkind result;

	switch(ideriv)
	{
	case 0:
		result = (*this)(x1,x2,x3,x4,x5,x6);
		break;
	case 1:
		result = ((*this)(x1+gridparams.gridspacing[0],x2,x3,x4,x5,x6)-(*this)(x1,x2,x3,x4,x5,x6));
		result /= gridparams.gridspacing[0];
		break;
	case 2:
		result = ((*this)(x1,x2+gridparams.gridspacing[1],x3,x4,x5,x6)-(*this)(x1,x2,x3,x4,x5,x6));
		result /= gridparams.gridspacing[1];
		break;
	default:
		break;
	}

	return result;

}

__host__
void XPgrid_polar::allocate(int min,int nin)
{
	m = min;
	n = nin;

	cudaMatrixr splinecoeff_temp(4,m,n);


	splinecoeff = splinecoeff_temp;

}

__host__
void XPgrid_polar::setup(double* spline_in,cudaMatrixr xgrid_in,cudaMatrixr ygrid_in,
											int ii1,int jj1,realkind hx1,realkind hy1,
											realkind hxi1,realkind hyi1,realkind xspani1,realkind yspani1)
{
	xspani = xspani1;
	yspani = yspani1;
	ii = ii1;
	jj = jj1;
	hx = hx1;
	hy = hy1;
	hxi = hxi1;
	hyi = hyi1;

	xgrid = xgrid_in;
	ygrid = ygrid_in;

	cudaMemcpydoubletoMatrixr(splinecoeff,spline_in);

}

__device__
void Environment::polarintrp(realkind rin,realkind thin,realkind2* params_in,int2* index_in)
{	// Verified
	realkind zxi;
	realkind zth;
	realkind zth8;
	realkind rimin = xigrid(0);
	realkind rimax = xigrid(nxi-1);
	realkind2 params;
	int2 index;

	zxi = fmax(rimin,fmin(rin,rimax));
	if ((thin >= thgrid(0))&&(thin <= thgrid(nth-1)))
	{
		zth = thin;
	}
	else
	{
		if (thin < thgrid(0)){zth = thin+twopi;}
		if (thin > thgrid(nth-1)){zth = thin-twopi;}
		if ((zth < thgrid(0))||(zth > thgrid(nth-1)))
		{
			zth8 = fmod(thin,thmax);
			if (thin < 0){zth8 = zth8+thmax;}
			zth = fmax(thgrid(0),fmin(thgrid(nth-1),zth8));
		}
	}
	index.x = lrint(((1+thspani*(zth-thgrid(0))*(nth-1))));
	index.x = min(nth-2,index.x)-1;
	if (thgrid(index.x) > zth){index.x = max(0,(index.x-1));}
	if (thgrid(index.x+1) < zth){index.x = min((nth-2),(index.x+1));}
	index.x = min(max(0,index.x),(nth-1));
	params.x = (zth-thgrid(index.x))/(thgrid(index.x+1)-thgrid(index.x));

	index.y = lrint((1+xispani*(zxi-xigrid(0))*(nxi-1)));
	index.y = min((nxi-2),index.y)-1;
	if (xigrid(index.y)>zxi){index.y -= 1;}
	if (xigrid(index.y+1) < zxi){index.y = min((nxi-2),(index.y+1));}
	index.y = min(max(0,index.y),(nxi-1));
	params.y = (zxi-xigrid(index.y))/(xigrid(index.y+1)-xigrid(index.y));

	params_in[0].x = params.x;
	params_in[0].y = params.y;
	index_in[0].x = min(max(0,index.x),(nth-2));
	index_in[0].y = min(max(0,index.y),(nxi-2));

	return;

}

template<enum XPgridderiv ideriv>
__device__
realkind XPgrid_polar::BCspline_eval(int2 index,realkind2 params)
{	// Verified

	// fval must be of the form fval[vectorlength,6]

	int i;
	int j;
	realkind sum = 0.0f;
	realkind xp;
	realkind xpi;
	realkind yp;
	realkind ypi;
	realkind xp2;
	realkind xpi2;
	realkind yp2;
	realkind ypi2;
	realkind cx;
	realkind cxi;
	realkind hx2;
	realkind cy;
	realkind cyi;
	realkind hy2;
	realkind cxd;
	realkind cxdi;
	realkind cyd;
	realkind cydi;
	realkind sixth = 0.166666666666666667f;


	i = max(0,index.x);
	j = max(0,index.y);

	xp=params.x;
	xpi=1.0f-xp;
	xp2=xp*xp;
	xpi2=xpi*xpi;

	cx=xp*(xp2-1.0f);
	cxi=xpi*(xpi2-1.0f);
	cxd = 3.0f*xp2-1.0f;
	cxdi= -3.0f*xpi2+1.0f;
	hx2=hx*hx;

	yp=params.y;
	ypi=1.0f-yp;
	yp2=yp*yp;
	ypi2=ypi*ypi;

	cy=yp*(yp2-1.0f);
	cyi=ypi*(ypi2-1.0f);
	cyd = 3.0f*yp2-1.0f;
	cydi= -3.0f*ypi2+1.0f;
	hy2=hy*hy;

	switch(ideriv)
	{
	case XPgridderiv_f:

		sum = xpi*(ypi*splinecoeff(0,i,j)+yp*splinecoeff(0,i,j+1))+
				   xp*(ypi*splinecoeff(0,i+1,j)+yp*splinecoeff(0,i+1,j+1));

		sum = sum + sixth*hx2*(cxi*(ypi*splinecoeff(1,i,j)+yp*splinecoeff(1,i,j+1))+
					 cx*(ypi*splinecoeff(1,i+1,j)+yp*splinecoeff(1,i+1,j+1)));

		sum = sum + sixth*hy2*(xpi*(cyi*splinecoeff(2,i,j)+cy*splinecoeff(2,i,j+1))+
					 xp*(cyi*splinecoeff(2,i+1,j)+cy*splinecoeff(2,i+1,j+1)));

		sum = sum+ sixth*sixth*hx2*hy2*(cxi*(cyi*splinecoeff(3,i,j)+cy*splinecoeff(3,i,j+1))+
					 cx*(cyi*splinecoeff(3,i+1,j)+cy*splinecoeff(3,i+1,j+1)));
	//	printf(" ---------------------------- \nrspline(%i,%i)\n%10.5f, %10.5f, %10.5f, %10.5f\n ---------------------------- \n",
	//			i,j,splinecoeff(0,i,j),splinecoeff(1,i,j),splinecoeff(2,i,j),splinecoeff(3,i,j));

		return sum;

		break;
	case XPgridderiv_dfdx:
		sum = hxi*(-(ypi*splinecoeff(0,i,j)+yp*splinecoeff(0,i,j+1))+
					(ypi*splinecoeff(0,i+1,j)+yp*splinecoeff(0,i+1,j+1)));

		sum += sixth*hx*(cxdi*(ypi*splinecoeff(1,i,j)+yp*splinecoeff(1,i,j+1))+
						cxd*(ypi*splinecoeff(1,i+1,j)+yp*splinecoeff(1,i+1,j+1)));

		sum += sixth*hxi*hy2*(-(cyi*splinecoeff(2,i,j)+cy*splinecoeff(2,i,j+1))+
					(cyi*splinecoeff(2,i+1,j)+cy*splinecoeff(2,i+1,j+1)));

		sum += sixth*sixth*hx*hy2*(cxdi*(cyi*splinecoeff(3,i,j)+cy*splinecoeff(3,i,j+1))+
					cxd*(cyi*splinecoeff(3,i+1,j)+cy*splinecoeff(3,i+1,j+1)));

		break;
	case XPgridderiv_dfdy:
		sum = hyi*(xpi*(-splinecoeff(0,i,j)+splinecoeff(0,i,j+1))+
					xp*(-splinecoeff(0,i+1,j)+splinecoeff(0,i+1,j+1)));

		sum += sixth*hx2*hyi*(cxi*(-splinecoeff(1,i,j)  +splinecoeff(1,i,j+1))+
			cx*(-splinecoeff(1,i+1,j)+splinecoeff(1,i+1,j+1)));

		sum += sixth*hy*(xpi*(cydi*splinecoeff(2,i,j)  +cyd*splinecoeff(2,i,j+1))+
			xp*(cydi*splinecoeff(2,i+1,j)+cyd*splinecoeff(2,i+1,j+1)));

		sum += sixth*sixth*hx2*hy*(cxi*(cydi*splinecoeff(3,i,j)  +cyd*splinecoeff(3,i,j+1))+
			cx*(cydi*splinecoeff(3,i+1,j)+cyd*splinecoeff(3,i+1,j+1)));

		break;
	case XPgridderiv_dfdxx:
		sum=(xpi*(ypi*splinecoeff(1,i,j)  +yp*splinecoeff(1,i,j+1))+
			xp*(ypi*splinecoeff(1,i+1,j)+yp*splinecoeff(1,i+1,j+1)));

		sum += sixth*hy2*(
			xpi*(cyi*splinecoeff(3,i,j)  +cy*splinecoeff(3,i,j+1))+
			xp*(cyi*splinecoeff(3,i+1,j)+cy*splinecoeff(3,i+1,j+1)));

		break;
	case XPgridderiv_dfdyy:
		sum=(xpi*(ypi*splinecoeff(2,i,j)  +yp*splinecoeff(2,i,j+1))+
			xp*(ypi*splinecoeff(2,i+1,j)+yp*splinecoeff(2,i+1,j+1)));

		sum += sixth*hx2*(cxi*(ypi*splinecoeff(3,i,j)  +yp*splinecoeff(3,i,j+1))+
			cx*(ypi*splinecoeff(3,i+1,j)+yp*splinecoeff(3,i+1,j+1)));

		break;
	case XPgridderiv_dfdxy:
		sum=hxi*hyi*(splinecoeff(0,i,j) -splinecoeff(0,i,j+1)
			-splinecoeff(0,i+1,j)+splinecoeff(0,i+1,j+1));

		sum += sixth*hx*hyi*(cxdi*(-splinecoeff(1,i,j)+splinecoeff(1,i,j+1))+
			cxd*(-splinecoeff(1,i+1,j)+splinecoeff(1,i+1,j+1)));

		sum += sixth*hxi*hy*(-(cydi*splinecoeff(2,i,j)+cyd*splinecoeff(2,i,j+1))
			+(cydi*splinecoeff(2,i+1,j)+cyd*splinecoeff(2,i+1,j+1)));

		sum += sixth*sixth*hx*hy*(cxdi*(cydi*splinecoeff(3,i,j)+cyd*splinecoeff(3,i,j+1))+
			cxd*(cydi*splinecoeff(3,i+1,j)+cyd*splinecoeff(3,i+1,j+1)));

		break;
	default:
		break;
	}


	return sum;
}


template<typename T,int dims>
__device__
int simple_XPgrid<T,dims>::limit_index(int index,int dim)
const
{
	return max(0,min((gridparams.griddims[dim]-1),index));
}

template<typename T,const int dims>
__device__
T & simple_XPgrid<T,dims>::operator()(realkind i1,realkind i2,realkind i3,realkind i4,realkind i5,realkind i6)
{
	unsigned int xindex = 0;
	unsigned int yindex = 0;
	unsigned int zindex = 0;

	xindex = limit_index(rint(i1),0);

	switch(dims)
	{
	case 1:
		yindex = 0;
		zindex = 0;
		break;
	case 2:
		yindex = limit_index(rint(i2),1);
		zindex = 0;
		break;
	case 3:
		yindex = limit_index(rint(i2),1);
		zindex = limit_index(rint(i3),2);
		break;
	case 4:
		yindex = limit_index(rint(i2),1);
		zindex = gridparams.griddims[2]*limit_index(rint(i4),3);
		zindex += limit_index(rint(i3),2);
		break;
	case 5:
		yindex = limit_index(rint(i2),1);
		zindex = gridparams.griddims[3]*limit_index(rint(i5),4);
		zindex += limit_index(rint(i4),3);
		zindex *= gridparams.griddims[2];
		zindex += limit_index(rint(i3),2);
		break;
	case 6:
		yindex = limit_index(rint(i2),1);
		zindex = gridparams.griddims[4]*limit_index(rint(i6),5);
		zindex += limit_index(rint(i5),4);
		zindex *= gridparams.griddims[3];
		zindex += limit_index(rint(i4),3);
		zindex *= gridparams.griddims[2];
		zindex += limit_index(rint(i3),2);
		break;
	default:
		break;
	}

	return data(xindex,yindex,zindex);

}

template<typename T,const int dims>
__device__
const T & simple_XPgrid<T,dims>::operator()(realkind i1,realkind i2,realkind i3,realkind i4,realkind i5,realkind i6)
const
{
	int xindex = 0;
	int yindex = 0;
	int zindex = 0;

	xindex = limit_index(rint(i1),0);

	switch(dims)
	{
	case 1:
		yindex = 0;
		zindex = 0;
		break;
	case 2:
		yindex = limit_index(rint(i2),1);
		zindex = 0;
		break;
	case 3:
		yindex = limit_index(rint(i2),1);
		zindex = limit_index(rint(i3),2);
		break;
	case 4:
		yindex = limit_index(rint(i2),1);
		zindex = gridparams.griddims[2]*limit_index(rint(i4),3);
		zindex += limit_index(rint(i3),2);
		break;
	case 5:
		yindex = limit_index(rint(i2),1);
		zindex = gridparams.griddims[3]*limit_index(rint(i5),4);
		zindex += limit_index(rint(i4),3);
		zindex *= gridparams.griddims[2];
		zindex += limit_index(rint(i3),2);
		break;
	case 6:
		yindex = limit_index(rint(i2),1);
		zindex = gridparams.griddims[4]*limit_index(rint(i6),5);
		zindex += limit_index(rint(i5),4);
		zindex *= gridparams.griddims[3];
		zindex += limit_index(rint(i4),3);
		zindex *= gridparams.griddims[2];
		zindex += limit_index(rint(i3),2);
		break;
	default:
		break;
	}

	return data(xindex,yindex,zindex);

}

__device__
realkind XPTextureGrid::operator()(realkind i1,realkind i2=0,realkind i3=0,realkind i4=0,realkind i5=0,realkind i6=0)
{
	realkind x = (i1-gridparams.origin[0])/(gridparams.gridspacing[0]);
	realkind y = (i2-gridparams.origin[1])/(gridparams.gridspacing[1]);
	realkind f00,f10,f01,f11;
	realkind result = 0.0f;


	realkind px = floor(x);
	realkind py = floor(y);
	x = x-px;
	y = y-py;



	f00 = pt2Function(px,py,0);
	f10 = pt2Function(px+1.0f,py,0);
	f01 = pt2Function(px,py+1.0f,0);
	f11 = pt2Function(px+1.0f,py+1.0f,0);

	result = f00;
	result += (f10-f00)*x;
	result += (f01-f00)*y;
	result += (f00-f10-f01+f11)*x*y;

	return result;

}

__device__
realkind XPCxGrid::operator()(realkind i1,realkind i2=0,realkind i3=0,realkind i4=0,realkind i5=0,realkind i6=0)
{
	realkind x;
	int xindex;
	int yindex;
	realkind my_energy = i1/2.5e7f;

	realkind f0;
	realkind f1;

	i2 = min((int)rint(i2),gridparams.griddims[1]);
	i3 = min((int)rint(i3),gridparams.griddims[2]);
	i4 = min((int)rint(i4),gridparams.griddims[3]);
	i5 = min((int)rint(i5),gridparams.griddims[4]);
	i6 = min((int)rint(i6),gridparams.griddims[5]);

	yindex = (rint(i2)+
				   gridparams.griddims[1]*(rint(i3)+
				   gridparams.griddims[2]*(rint(i4)+
				   gridparams.griddims[3]*(rint(i5)+
				   gridparams.griddims[4]*rint(i6)))));



	x = log10(my_energy+0.0001f)*0.25f+1.0f;


	x *= ((realkind)Max_energy_sectors);

	xindex = floor(x);

	//printf("xindex = %i, yindex = %i\n",xindex,yindex);

	f0 = pt2Function(xindex,yindex,0);




	return f0;

}





__host__
void Environment::setup_parameters(int* intparams,double* dbleparams)
{

	double Rmin_temp = dbleparams[5];
	double Rmax_temp = dbleparams[6];
	double Zmin_temp = dbleparams[7];
	double Zmax_temp = dbleparams[8];

	ntransp_zones = intparams[0];
	zonebdyctr_shift_index = intparams[1];
	nspecies = intparams[2];
	max_species = intparams[3];
	nxi = intparams[4];
	nth = intparams[5];
	nbeams = intparams[6];
	ledge_transp = intparams[7];
	lcenter_transp = intparams[8];
	nzones = intparams[9];

	nthermal_species = intparams[10];
	max_particles = intparams[11];
	phi_ccw = intparams[12];



	midplane_symetry = intparams[13];
	nbeam_zones = intparams[14];

	nbeam_zones_inside = intparams[15];
	nxi_rows = intparams[16];
	nxi_rows_inside = intparams[17];
	nrow_zones = intparams[18];
	last_inside_row = intparams[19];
	n_diffusion_energy_bins = intparams[20];
	ngases = intparams[21];
	nr = intparams[22];
	nz = intparams[23];
	nint = intparams[24];
	next = intparams[25];

	sign_bphi = intparams[29];

	nbsii = intparams[27];
	nbsjj = intparams[28];

	xi_boundary = dbleparams[0];
	theta_body0 = dbleparams[1];
	theta_body1 = dbleparams[2];
	average_weight_factor = max(1.0,dbleparams[3]);
	energy_factor = dbleparams[4];
	Rmin = dbleparams[5];

	Zmin = dbleparams[7];


	fppcon = dbleparams[9];
	cxpcon = dbleparams[10];

	cx_cross_sections.max_energy = dbleparams[11];

	xi_max = dbleparams[14];

	cx_cross_sections.minz = intparams[30];
	cx_cross_sections.maxz = intparams[31];

	griddims.x = nr;
	griddims.y = nz;
	gridspacing.x = dbleparams[12];
	gridspacing.y = dbleparams[13];

	Rmax = nr*gridspacing.x+Rmin;
	Zmax = nz*gridspacing.y+Zmin;



}

__device__
realkind2 cxnsum_intrp(realkind my_energy,realkind* energies,int* last_grid_point,
								  int* nranges,int* npoints,int irange,int idBeam)
{

	int imin;
	int imax;
	int inum;
	int inc;
	realkind emin;
	realkind emax;
	unsigned int itry = 0;

	int eindex;

	int my_range_sectors = nranges[idBeam]-1;
	int my_total_points = npoints[idBeam]-1;

	realkind2 result;

	my_energy = max(energies[0],min(energies[my_total_points],my_energy));

	irange = max(0,min((irange),my_range_sectors));


	if(irange == 0) imin = 1;
	else imin = last_grid_point[irange-1+4*idBeam]-1;

	imin = max(1,imin);
	imax = last_grid_point[irange+4*idBeam]-1;
	imax = min(imax,my_total_points+1);

	emin = energies[imin-1];
	emax = energies[imax-1];



	while((my_energy < emin)||(my_energy > emax))
	{
		irange = max(0,min((irange),my_range_sectors));

		if(irange == 0) imin = 1;
		else imin = last_grid_point[irange-1+4*idBeam]-1;

		imin = max(1,imin);

		imax = last_grid_point[irange+4*idBeam]-1;
		imax = min(imax,my_total_points);


		emin = energies[imin-1];
		emax = energies[imax-1];

		if(my_energy < emin){ irange-= 1;}
		else if(my_energy > emax){ irange+=1;}
		else break;

		if(itry > 10)
			break;



		itry++;
	}





	inum = imax - imin;

	inc = min((inum-2),((int)rint(((realkind)(inum))*((my_energy-emin)/(emax-emin)))));

	eindex = imin+inc-1;

	eindex = max(0,min((my_total_points-1),eindex));


//	if(((blockIdx.x+blockIdx.y+blockIdx.z) == 0)&&(threadIdx.x>0))
//	{printf("Energies = %g,%g,%g = energy[%i] = %g, %g\n",my_energy,emin,emax,eindex,energies[eindex],energies[eindex+1]);}

	result.x = (my_energy-energies[eindex])/(energies[eindex+1]-energies[eindex]);

	result.y = ((realkind)eindex)+0.01;

	return result;

}

__device__
unsigned int get_data_index(int eidx,int* dimfacts,int dimidx,int dimbidx,int dimbidy,int dimbidz)
{
	unsigned int bidx = blockIdx.x;
	unsigned int idBeam = blockIdx.z;
	unsigned int bidy = blockIdx.y;

	unsigned int result = 0;

	result += dimfacts[dimidx]*eidx;
	result += dimfacts[dimbidx]*bidx;
	result += dimfacts[dimbidy]*bidy;
	result += dimfacts[dimbidz]*idBeam;

	return result;
}



__global__
void setup_cross_sections_kernel(cudaMatrixr data_out,cudaMatrixd data_in,
											 int* npoints,int* last_grid_point,int* nranges,
											 double* energies_in,int max_energy_points,
											 realkind max_energy,int ndim3,
											 int* dimfacts,int dimidx,int dimbidx,int dimbidy,int dimbidz)
{
	unsigned int idx = threadIdx.x;
	unsigned int bidx = blockIdx.x;
	unsigned int idBeam = blockIdx.z;
	unsigned int bidy = blockIdx.y;
	unsigned int tid = 0;

	realkind nenergy_sectors = Max_energy_sectors;

	realkind my_energy;

	int irange = idx / (Max_energy_sectors/4);

	unsigned int data_index[4];
	unsigned int data_index1[4];

	realkind2 tempfactor;
	realkind intrp_factor;

	double data_0;
	double data_1;
	int eindex;


	realkind temp_data;


	my_energy = max_energy*(exp10(4.0*((realkind)idx)/(nenergy_sectors)-4.0)-0.0001); // Using an exponential function that closely matches the range method

	__shared__ realkind energies[400];

	while(idx+tid < 400)
	{
		energies[idx+tid]  = energies_in[idx+tid+400*idBeam];
		tid += blockDim.x;
	}
	__syncthreads();

	//if(((blockIdx.x+blockIdx.y+blockIdx.z) == 0)&&(threadIdx.x>100))
	//{printf("threadID = %i, energy = %g \n",threadIdx.x,my_energy);}

	tempfactor  = cxnsum_intrp(my_energy,energies,last_grid_point,nranges,npoints,irange,idBeam);

	intrp_factor = tempfactor.x;
	eindex = (int)floor(tempfactor.y);

//	data_index = get_data_index(eindex,dimfacts,dimidx,dimbidx,dimbidy,dimbidz);
//	data_index1 = get_data_index(eindex+1,dimfacts,dimidx,dimbidx,dimbidy,dimbidz);

	data_index[dimidx] = eindex;
	data_index[dimbidx] = bidx;
	data_index[dimbidy] = bidy;
	data_index[dimbidz] = idBeam;
	data_index1[dimidx] = eindex+1;
	data_index1[dimbidx] = bidx;
	data_index1[dimbidy] = bidy;
	data_index1[dimbidz] = idBeam;

	data_0 = data_in(data_index[0],data_index[1],data_index[2]+ndim3*data_index[3]);
	data_1 = data_in(data_index1[0],data_index1[1],data_index1[2]+ndim3*data_index1[3]);


	temp_data = (1.0-intrp_factor)*data_0+intrp_factor*data_1;

	data_out(idx,0,bidx+gridDim.x*(bidy+gridDim.y*idBeam)) = temp_data;
/*
	if(((blockIdx.x+blockIdx.y+blockIdx.z) == 0)&&(threadIdx.x>1))
	{printf("cross_section(%i,%i,%i,%i) = (1-%g)*%g+%g*%g = %g\nfor energy %g < %g < %g \n",
			data_index[0],data_index[1],data_index[2],data_index[3],
			intrp_factor,data_0,intrp_factor,data_1,temp_data,
			energies[eindex],my_energy,energies[eindex+1]);}
*/

}



__host__
void XPCxGrid::setup_cross_section(double* data_in,int* npoints_d,int* last_grid_point_d,int* nranges_d,
																	  double* energies_in_d,realkind max_energy_in,int* dims,
																	   int dimidx,int dimbidx,int dimbidy,int dimbidz,int ndims_in)
{
	texturetype = crossSection;
	tdims = 1;
	ndims = ndims_in;


	int dimfacts[6] = {1,1,1,1,1,1};
	int esectors = Max_energy_sectors;
	int data_size = 1;
	int nbnsvmx = dims[dimidx];
	int ndim3 = dims[2];
	int* dimfacts_d;
	char* texrefstring = (char*)malloc(sizeof(char)*30);
	char* texfetchstring = (char*)malloc(sizeof(char)*30);

	for(int i=0;i<6;i++)
	{
		gridparams.griddims[i] = max(gridparams.griddims[i],1);
		dims[i] = max(dims[i],1);
	}

	max_energy = max_energy_in;
	//dims[dimidx] = 1;

	CUDA_SAFE_KERNEL(cudaMalloc((void**)&dimfacts_d,6*sizeof(int)));

	gridparams.gridspacing[0] = max_energy/Max_energy_sectors;

	for(int i = 1;i<(ndims+tdims-1);i++)
	{

		dimfacts[i] = dims[i-1]*dimfacts[i-1];
		printf("dimfacts[%i] = %i , dims = %i\n",i,dimfacts[i],dims[i]);
		gridparams.gridspacing[i] = 1.0;
	}

	// Find a free texture reference and take it

	int itemp = next_tex1DLayered;
	next_tex1DLayered++;

	printf("getting texture # %i\n",itemp);
	sprintf(texrefstring,"texref1DLayered%i",itemp);
	sprintf(texfetchstring,"fetchtexref1DLayeredPtr%i",itemp);
	my_array_reference = itemp;

	symbol = texrefstring;
	CUDA_SAFE_KERNEL(cudaMemcpyFromSymbol(&pt2Function,texfetchstring,sizeof(texFunctionPtr)));

	for(int i=0;i<(ndims+tdims);i++)
		data_size *= dims[i];

	realkind min_energy = 0.0;
	realkind energy_limit = max_energy;
	printf("Max_energy = %g\n",energy_limit);

	cudaError status;
	dim3 cudaGridSize(dims[dimbidx],dims[dimbidy],dims[dimbidz]);
	dim3 cudaBlockSize(Max_energy_sectors,1,1);

	cudaMatrixr tempdata(esectors,1,cudaGridSize.x*cudaGridSize.y*cudaGridSize.z);
	cudaMatrixd data_in_matrix(dims[0],dims[1],dims[2]*dims[3]);

	cudaDeviceSynchronize();

	CUDA_SAFE_KERNEL((data_in_matrix.cudaMatrixcpyHostToDevice(data_in)));


	cudaExtent extent;
	cudaPitchedPtr matrixPtr;

	cudaMemcpy3DParms params = {0};
	params.kind = cudaMemcpyDeviceToDevice;
#ifdef __double_precision
	cudaChannelFormatDesc desc = cudaCreateChannelDesc(32,32,0,0,cudaChannelFormatKindSigned);
#else
	cudaChannelFormatDesc desc = cudaCreateChannelDesc<float>();
#endif


	printf(" data size = %i \n",data_size);
	//cudaMalloc((void**)&data_in_d,data_size*sizeof(double));
	//CUDA_SAFE_CALL(cudaMemcpy(data_in_d,data_in,data_size*sizeof(double),cudaMemcpyHostToDevice));

	CUDA_SAFE_KERNEL((matrixPtr = tempdata.getptr()));

	CUDA_SAFE_KERNEL(cudaMemcpy(dimfacts_d,dimfacts,6*sizeof(int),cudaMemcpyHostToDevice));

	CUDA_SAFE_KERNEL((setup_cross_sections_kernel<<<cudaGridSize,cudaBlockSize>>>(
												tempdata,data_in_matrix,
												 npoints_d,last_grid_point_d,nranges_d,
												 energies_in_d,nbnsvmx,
												 energy_limit,ndim3,
												 dimfacts_d,dimidx,dimbidx,dimbidy,dimbidz)));

	cudaDeviceSynchronize();

	printf("cudaGridSize = %i, %i, %i \n",cudaGridSize.x,cudaGridSize.y,cudaGridSize.z);
	extent = make_cudaExtent(esectors,0,cudaGridSize.x*cudaGridSize.y*cudaGridSize.z);
	CUDA_SAFE_CALL(cudaMalloc3DArray(&cuArray,&desc,extent,cudaArrayLayered));

	params.srcPtr = matrixPtr;
	params.dstArray = cuArray;
	params.extent = make_cudaExtent(esectors,1,cudaGridSize.x*cudaGridSize.y*cudaGridSize.z);;

	cudaDeviceSynchronize();
	CUDA_SAFE_CALL(cudaMemcpy3D(&params));

	cudaDeviceSynchronize();
	const textureReference* texRefPtr;
	CUDA_SAFE_CALL(cudaGetTextureReference(&texRefPtr, symbol));
	cudaChannelFormatDesc channelDesc;
	cudaGetChannelDesc(&channelDesc, cuArray);
	CUDA_SAFE_CALL(cudaBindTextureToArray(texRefPtr, cuArray, &channelDesc));

	//cudaFree(data_in_d);
	free(texrefstring);
	free(texfetchstring);
	tempdata.cudaMatrixFree();
	data_in_matrix.cudaMatrixFree();
	CUDA_SAFE_CALL(cudaFree(dimfacts_d));




}

__host__
void Environment::setup_cross_sections(int* nbnsve,int* lbnsve,int* nbnsver,
										double* bnsves,
										double* bnsvtot,double* bnsvexc,
										double* bnsviif,double* bnsvief,double* bnsvizf,
										double* bnsvcxf,double* bbnsvcx,double* bbnsvii,
										double* cxn_thcx_a,double* cxn_thcx_wa,double* cxn_thii_wa,
										double* cxn_thcx_ha,double* cxn_thii_ha,double* cxn_bbcx,
										double* cxn_bbii,double* btfus_dt,double* btfus_d3,
										double* btfus_ddn,double* btfus_ddp,double* btfus_td,
										double* btfus_tt,double* btfus_3d)
{

	int ncross_sections = 22;

	int nbnsvmx = 400;
	int lep1 = ledge_transp+1;
	int nsbeam = nspecies;
	int nfbznsi = nbeam_zones_inside;
	int ng = ngases;
	int cxn_zmin = cx_cross_sections.minz;
	int cxn_zmax = cx_cross_sections.maxz;

	int ndims;
	int dimfacts[6] = {1,1,1,1,1,1};
	int dimidx;
	int dimbidx;
	int dimbidy;
	int dimbidz;
	int esectors = Max_energy_sectors;

	realkind min_energy = 0.0;
	realkind energy_limit = cx_cross_sections.max_energy;

	cudaError status;
	cudaExtent extent;
	dim3 cudaGridSize(1,1,1);
	dim3 cudaBlockSize(Max_energy_sectors,1,1);



	int* npoints_d;
	int* last_grid_point_d;
	int* nranges_d;
	int data_size;
	double* energies_in_d;
	double* data_in_d;

	cudaMalloc((void**)&npoints_d,(nsbeam+1)*sizeof(int));
	cudaMalloc((void**)&last_grid_point_d,4*(nsbeam+1)*sizeof(int));
	cudaMalloc((void**)&nranges_d,(nsbeam+1)*sizeof(int));
	cudaMalloc((void**)&energies_in_d,nbnsvmx*(nsbeam+1)*sizeof(double));

	CUDA_SAFE_CALL(cudaMemcpy(npoints_d,nbnsve,(nsbeam+1)*sizeof(int),cudaMemcpyHostToDevice));
	CUDA_SAFE_CALL(cudaMemcpy(last_grid_point_d,lbnsve,4*(nsbeam+1)*sizeof(int),cudaMemcpyHostToDevice));
	CUDA_SAFE_CALL(cudaMemcpy(nranges_d,nbnsver,(nsbeam+1)*sizeof(int),cudaMemcpyHostToDevice));
	CUDA_SAFE_CALL(cudaMemcpy(energies_in_d,bnsves,nbnsvmx*(nsbeam+1)*sizeof(double),cudaMemcpyHostToDevice));

	// Setup each grid

	// bnsvtot
	ndims = 3;
	dimfacts[0] = lep1;
	dimfacts[1] = nbnsvmx;
	dimfacts[2] = nsbeam;
	dimfacts[3] = 1;

	dimidx = 1;
	dimbidx = 0;
	dimbidy = 3;
	dimbidz = 2;
	cx_cross_sections.thermal_total.gridparams.griddims[0] = esectors;
	cx_cross_sections.thermal_total.gridparams.griddims[1] = lep1;
	cx_cross_sections.thermal_total.gridparams.griddims[2] = nsbeam;

	cx_cross_sections.thermal_total.setup_cross_section(bnsvtot,npoints_d,last_grid_point_d,nranges_d,
																					energies_in_d,energy_limit,dimfacts,dimidx,dimbidx,dimbidy,dimbidz,ndims);

	// bnsvexc
	ndims = 3;
	dimfacts[0] = lep1;
	dimfacts[1] = nbnsvmx;
	dimfacts[2] = nsbeam;
	dimfacts[3] = 1;

	dimidx = 1;
	dimbidx = 0;
	dimbidy = 3;
	dimbidz = 2;
	cx_cross_sections.excitation_estimate.gridparams.griddims[0] = esectors;
	cx_cross_sections.excitation_estimate.gridparams.griddims[1] = lep1;
	cx_cross_sections.excitation_estimate.gridparams.griddims[2] = nsbeam;

	cx_cross_sections.excitation_estimate.setup_cross_section(bnsvexc,npoints_d,last_grid_point_d,nranges_d,
																					energies_in_d,energy_limit,dimfacts,dimidx,dimbidx,dimbidy,dimbidz,ndims);

	// bnsviif
	ndims = 3;
	dimfacts[0] = lep1;
	dimfacts[1] = nbnsvmx;
	dimfacts[2] = nsbeam;
	dimfacts[3] = 1;

	dimidx = 1;
	dimbidx = 0;
	dimbidy = 3;
	dimbidz = 2;
	cx_cross_sections.thermal_fraction.gridparams.griddims[0] = esectors;
	cx_cross_sections.thermal_fraction.gridparams.griddims[1] = lep1;
	cx_cross_sections.thermal_fraction.gridparams.griddims[2] = nsbeam;

	cx_cross_sections.thermal_fraction.setup_cross_section(bnsviif,npoints_d,last_grid_point_d,nranges_d,
																					energies_in_d,energy_limit,dimfacts,dimidx,dimbidx,dimbidy,dimbidz,ndims);

	// bnsvief
	ndims = 3;
	dimfacts[0] = lep1;
	dimfacts[1] = nbnsvmx;
	dimfacts[2] = nsbeam;
	dimfacts[3] = 1;

	dimidx = 1;
	dimbidx = 0;
	dimbidy = 3;
	dimbidz = 2;
	cx_cross_sections.electron_fraction.gridparams.griddims[0] = esectors;
	cx_cross_sections.electron_fraction.gridparams.griddims[1] = lep1;
	cx_cross_sections.electron_fraction.gridparams.griddims[2] = nsbeam;

	cx_cross_sections.electron_fraction.setup_cross_section(bnsvief,npoints_d,last_grid_point_d,nranges_d,
																					energies_in_d,energy_limit,dimfacts,dimidx,dimbidx,dimbidy,dimbidz,ndims);

	// bnsvizf
	ndims = 3;
	dimfacts[0] = lep1;
	dimfacts[1] = nbnsvmx;
	dimfacts[2] = nsbeam;
	dimfacts[3] = 1;

	dimidx = 1;
	dimbidx = 0;
	dimbidy = 3;
	dimbidz = 2;
	cx_cross_sections.impurity_fraction.gridparams.griddims[0] = esectors;
	cx_cross_sections.impurity_fraction.gridparams.griddims[1] = lep1;
	cx_cross_sections.impurity_fraction.gridparams.griddims[2] = nsbeam;

	cx_cross_sections.impurity_fraction.setup_cross_section(bnsvizf,npoints_d,last_grid_point_d,nranges_d,
																					energies_in_d,energy_limit,dimfacts,dimidx,dimbidx,dimbidy,dimbidz,ndims);

	//bnsvcxf
	ndims = 4;
	dimfacts[0] = lep1;
	dimfacts[1] = ng;
	dimfacts[2] = nbnsvmx;
	dimfacts[3] = nsbeam;

	dimidx = 2;
	dimbidx = 0;
	dimbidy = 1;
	dimbidz =3;
	cx_cross_sections.cx_fraction.gridparams.griddims[0] = esectors;
	cx_cross_sections.cx_fraction.gridparams.griddims[1] = lep1;
	cx_cross_sections.cx_fraction.gridparams.griddims[2] = ng;
	cx_cross_sections.cx_fraction.gridparams.griddims[3] = nsbeam;

	cx_cross_sections.cx_fraction.setup_cross_section(bnsvcxf,npoints_d,last_grid_point_d,nranges_d,
																					energies_in_d,energy_limit,dimfacts,dimidx,dimbidx,dimbidy,dimbidz,ndims);

	// bbnsvcx
	ndims = 4;
	dimfacts[0] = nfbznsi;
	dimfacts[1] = nbnsvmx;
	dimfacts[2] = nsbeam;
	dimfacts[3] = nsbeam;

	dimidx = 1;
	dimbidx = 0;
	dimbidy = 2;
	dimbidz =3;
	cx_cross_sections.beam_beam_cx.gridparams.griddims[0] = esectors;
	cx_cross_sections.beam_beam_cx.gridparams.griddims[1] = nfbznsi;
	cx_cross_sections.beam_beam_cx.gridparams.griddims[2] = nsbeam;
	cx_cross_sections.beam_beam_cx.gridparams.griddims[3] = nsbeam;

	cx_cross_sections.beam_beam_cx.setup_cross_section(bbnsvcx,npoints_d,last_grid_point_d,nranges_d,
																					energies_in_d,energy_limit,dimfacts,dimidx,dimbidx,dimbidy,dimbidz,ndims);

	// bbnsvii
	ndims = 4;
	dimfacts[0] = nfbznsi;
	dimfacts[1] = nbnsvmx;
	dimfacts[2] = nsbeam;
	dimfacts[3] = nsbeam;

	dimidx = 1;
	dimbidx = 0;
	dimbidy = 2;
	dimbidz =3;
	cx_cross_sections.beam_beam_ii.gridparams.griddims[0] = esectors;
	cx_cross_sections.beam_beam_ii.gridparams.griddims[1] = nfbznsi;
	cx_cross_sections.beam_beam_ii.gridparams.griddims[2] = nsbeam;
	cx_cross_sections.beam_beam_ii.gridparams.griddims[3] = nsbeam;

	cx_cross_sections.beam_beam_ii.setup_cross_section(bbnsvii,npoints_d,last_grid_point_d,nranges_d,
																					energies_in_d,energy_limit,dimfacts,dimidx,dimbidx,dimbidy,dimbidz,ndims);

	// cxn_thcx_a
	ndims = 3;
	dimfacts[0] = ng;
	dimfacts[1] = nbnsvmx;
	dimfacts[2] = nsbeam;
	dimfacts[3] = 1;

	dimidx = 1;
	dimbidx = 0;
	dimbidy = 3;
	dimbidz =2;
	cx_cross_sections.cx_outside_plasma.gridparams.griddims[0] = esectors;
	cx_cross_sections.cx_outside_plasma.gridparams.griddims[1] = ng;
	cx_cross_sections.cx_outside_plasma.gridparams.griddims[2] = nsbeam;

	cx_cross_sections.cx_outside_plasma.setup_cross_section(cxn_thcx_a,npoints_d,last_grid_point_d,nranges_d,
																					energies_in_d,energy_limit,dimfacts,dimidx,dimbidx,dimbidy,dimbidz,ndims);

	// cxn_thcx_wa
	printf(" cxn_thcx_wa(%i,%i,%i,%i)\n",ng,lep1,nbnsvmx,nsbeam);
	ndims = 4;
	dimfacts[0] = ng;
	dimfacts[1] = lep1;
	dimfacts[2] = nbnsvmx;
	dimfacts[3] = nsbeam;

	dimidx = 2;
	dimbidx = 1;
	dimbidy = 0;
	dimbidz =3;
	cx_cross_sections.cx_thcx_wall.gridparams.griddims[0] = esectors;
	cx_cross_sections.cx_thcx_wall.gridparams.griddims[1] = lep1;
	cx_cross_sections.cx_thcx_wall.gridparams.griddims[2] = ng;
	cx_cross_sections.cx_thcx_wall.gridparams.griddims[3] = nsbeam;

	cx_cross_sections.cx_thcx_wall.setup_cross_section(cxn_thcx_wa,npoints_d,last_grid_point_d,nranges_d,
																					energies_in_d,energy_limit,dimfacts,dimidx,dimbidx,dimbidy,dimbidz,ndims);

	// cxn_thii_wa
	printf(" cxn_thii_wa(%i,%i,%i,%i)\n",ng,lep1,nbnsvmx,nsbeam);
	ndims = 4;
	dimfacts[0] = ng;
	dimfacts[1] = lep1;
	dimfacts[2] = nbnsvmx;
	dimfacts[3] = nsbeam;

	dimidx = 2;
	dimbidx = 1;
	dimbidy = 0;
	dimbidz =3;
	cx_cross_sections.cx_thii_wall.gridparams.griddims[0] = esectors;
	cx_cross_sections.cx_thii_wall.gridparams.griddims[1] = lep1;
	cx_cross_sections.cx_thii_wall.gridparams.griddims[2] = ng;
	cx_cross_sections.cx_thii_wall.gridparams.griddims[3] = nsbeam;

	cx_cross_sections.cx_thii_wall.setup_cross_section(cxn_thii_wa,npoints_d,last_grid_point_d,nranges_d,
																					energies_in_d,energy_limit,dimfacts,dimidx,dimbidx,dimbidy,dimbidz,ndims);

	// cxn_thcx_ha
	printf(" cxn_thcx_ha(%i,%i,%i,%i)\n",ng,nfbznsi,nbnsvmx,nsbeam);
	ndims = 4;
	dimfacts[0] = ng;
	dimfacts[1] = nfbznsi;
	dimfacts[2] = nbnsvmx;
	dimfacts[3] = nsbeam;

	dimidx = 2;
	dimbidx = 1;
	dimbidy = 0;
	dimbidz = 3;
	cx_cross_sections.cx_thcx_halo.gridparams.griddims[0] = esectors;
	cx_cross_sections.cx_thcx_halo.gridparams.griddims[1] = nfbznsi;
	cx_cross_sections.cx_thcx_halo.gridparams.griddims[2] = ng;
	cx_cross_sections.cx_thcx_halo.gridparams.griddims[3] = nsbeam;

	cx_cross_sections.cx_thcx_halo.setup_cross_section(cxn_thcx_ha,npoints_d,last_grid_point_d,nranges_d,
																					energies_in_d,energy_limit,dimfacts,dimidx,dimbidx,dimbidy,dimbidz,ndims);

	// cxn_thii_ha
	printf(" cxn_thii_ha(%i,%i,%i,%i)\n",ng,nfbznsi,nbnsvmx,nsbeam);
	ndims = 4;
	dimfacts[0] = ng;
	dimfacts[1] = nfbznsi;
	dimfacts[2] = nbnsvmx;
	dimfacts[3] = nsbeam;

	dimidx = 2;
	dimbidx = 1;
	dimbidy = 0;
	dimbidz = 3;
	cx_cross_sections.cx_thii_halo.gridparams.griddims[0] = esectors;
	cx_cross_sections.cx_thii_halo.gridparams.griddims[1] = nfbznsi;
	cx_cross_sections.cx_thii_halo.gridparams.griddims[2] = ng;
	cx_cross_sections.cx_thii_halo.gridparams.griddims[3] = nsbeam;

	cx_cross_sections.cx_thii_halo.setup_cross_section(cxn_thii_ha,npoints_d,last_grid_point_d,nranges_d,
																					energies_in_d,energy_limit,dimfacts,dimidx,dimbidx,dimbidy,dimbidz,ndims);

	// cxn_bbcx
	printf(" cxn_bbcx \n");
	ndims = 3;
	dimfacts[0] = cxn_zmax-cxn_zmin+1;
	dimfacts[1] = nbnsvmx;
	dimfacts[2] = cxn_zmax-cxn_zmin+1;
	dimfacts[3] = 1;

	dimidx = 1;
	dimbidx = 0;
	dimbidy = 3;
	dimbidz = 2;
	cx_cross_sections.cx_thcx_beam_beam.gridparams.griddims[0] = esectors;
	cx_cross_sections.cx_thcx_beam_beam.gridparams.griddims[1] = cxn_zmax-cxn_zmin+1;
	cx_cross_sections.cx_thcx_beam_beam.gridparams.griddims[2] = cxn_zmax-cxn_zmin+1;

	cx_cross_sections.cx_thcx_beam_beam.gridparams.origin[0] = 0;
	cx_cross_sections.cx_thcx_beam_beam.gridparams.origin[1] = cxn_zmin-1;
	cx_cross_sections.cx_thcx_beam_beam.gridparams.origin[2] = cxn_zmin-1;

	cx_cross_sections.cx_thcx_beam_beam.setup_cross_section(cxn_bbcx,npoints_d,last_grid_point_d,nranges_d,
																					energies_in_d,energy_limit,dimfacts,dimidx,dimbidx,dimbidy,dimbidz,ndims);

	// cxn_bbii
	printf(" cxn_bbii \n");
	ndims = 3;
	dimfacts[0] = cxn_zmax-cxn_zmin+1;
	dimfacts[1] = nbnsvmx;
	dimfacts[2] = cxn_zmax-cxn_zmin+1;
	dimfacts[3] = 1;

	dimidx = 1;
	dimbidx = 0;
	dimbidy = 3;
	dimbidz = 2;
	cx_cross_sections.cx_thii_beam_beam.gridparams.griddims[0] = esectors;
	cx_cross_sections.cx_thii_beam_beam.gridparams.griddims[1] = cxn_zmax-cxn_zmin+1;
	cx_cross_sections.cx_thii_beam_beam.gridparams.griddims[2] = cxn_zmax-cxn_zmin+1;

	cx_cross_sections.cx_thii_beam_beam.gridparams.origin[0] = 0;
	cx_cross_sections.cx_thii_beam_beam.gridparams.origin[1] = cxn_zmin-1;
	cx_cross_sections.cx_thii_beam_beam.gridparams.origin[2] = cxn_zmin-1;

	cx_cross_sections.cx_thii_beam_beam.setup_cross_section(cxn_bbii,npoints_d,last_grid_point_d,nranges_d,
																					energies_in_d,energy_limit,dimfacts,dimidx,dimbidx,dimbidy,dimbidz,ndims);
// Don't need these for now
/*
	// btfus_dt
	printf(" btfus_dt \n");
	ndims = 2;
	dimfacts[0] = lep1;
	dimfacts[1] = nbnsvmx;
	dimfacts[2] = 1;
	dimfacts[3] = 1;

	dimidx = 1;
	dimbidx = 0;
	dimbidy = 3;
	dimbidz = 2;
	cx_cross_sections.btfus_dt.griddims[0] = esectors;
	cx_cross_sections.btfus_dt.griddims[1] = lep1;

	cx_cross_sections.btfus_dt.setup_cross_section(btfus_dt,npoints_d,last_grid_point_d,nranges_d,
																			energies_in_d,energy_limit,dimfacts,dimidx,dimbidx,dimbidy,dimbidz,ndims);

	// btfus_d3
	printf(" btfus_d3 \n");
	ndims = 2;
	dimfacts[0] = lep1;
	dimfacts[1] = nbnsvmx;
	dimfacts[2] = 1;
	dimfacts[3] = 1;

	dimidx = 1;
	dimbidx = 0;
	dimbidy = 3;
	dimbidz = 2;
	cx_cross_sections.btfus_d3.griddims[0] = esectors;
	cx_cross_sections.btfus_d3.griddims[1] = lep1;

	cx_cross_sections.btfus_d3.setup_cross_section(btfus_d3,npoints_d,last_grid_point_d,nranges_d,
																			energies_in_d,energy_limit,dimfacts,dimidx,dimbidx,dimbidy,dimbidz,ndims);

	// btfus_ddn
	ndims = 2;
	dimfacts[0] = lep1;
	dimfacts[1] = nbnsvmx;
	dimfacts[2] = 1;
	dimfacts[3] = 1;

	dimidx = 1;
	dimbidx = 0;
	dimbidy = 3;
	dimbidz = 2;
	cx_cross_sections.btfus_ddn.griddims[0] = esectors;
	cx_cross_sections.btfus_ddn.griddims[1] = lep1;

	cx_cross_sections.btfus_ddn.setup_cross_section(btfus_ddn,npoints_d,last_grid_point_d,nranges_d,
																			energies_in_d,energy_limit,dimfacts,dimidx,dimbidx,dimbidy,dimbidz,ndims);

	// btfus_ddp
	ndims = 2;
	dimfacts[0] = lep1;
	dimfacts[1] = nbnsvmx;
	dimfacts[2] = 1;
	dimfacts[3] = 1;

	dimidx = 1;
	dimbidx = 0;
	dimbidy = 3;
	dimbidz = 2;
	cx_cross_sections.btfus_ddp.griddims[0] = esectors;
	cx_cross_sections.btfus_ddp.griddims[1] = lep1;

	cx_cross_sections.btfus_ddp.setup_cross_section(btfus_ddp,npoints_d,last_grid_point_d,nranges_d,
																			energies_in_d,energy_limit,dimfacts,dimidx,dimbidx,dimbidy,dimbidz,ndims);

	// btfus_td
	ndims = 2;
	dimfacts[0] = lep1;
	dimfacts[1] = nbnsvmx;
	dimfacts[2] = 1;
	dimfacts[3] = 1;

	dimidx = 1;
	dimbidx = 0;
	dimbidy = 3;
	dimbidz = 2;
	cx_cross_sections.btfus_td.griddims[0] = esectors;
	cx_cross_sections.btfus_td.griddims[1] = lep1;

	cx_cross_sections.btfus_td.setup_cross_section(btfus_td,npoints_d,last_grid_point_d,nranges_d,
																			energies_in_d,energy_limit,dimfacts,dimidx,dimbidx,dimbidy,dimbidz,ndims);

	// btfus_tt
	ndims = 2;
	dimfacts[0] = lep1;
	dimfacts[1] = nbnsvmx;
	dimfacts[2] = 1;
	dimfacts[3] = 1;

	dimidx = 1;
	dimbidx = 0;
	dimbidy = 3;
	dimbidz = 2;
	cx_cross_sections.btfus_tt.griddims[0] = esectors;
	cx_cross_sections.btfus_tt.griddims[1] = lep1;

	cx_cross_sections.btfus_tt.setup_cross_section(btfus_tt,npoints_d,last_grid_point_d,nranges_d,
																			energies_in_d,energy_limit,dimfacts,dimidx,dimbidx,dimbidy,dimbidz,ndims);

	// btfus_3d
	ndims = 2;
	dimfacts[0] = lep1;
	dimfacts[1] = nbnsvmx;
	dimfacts[2] = 1;
	dimfacts[3] = 1;

	dimidx = 1;
	dimbidx = 0;
	dimbidy = 3;
	dimbidz = 2;
	cx_cross_sections.btfus_3d.griddims[0] = esectors;
	cx_cross_sections.btfus_3d.griddims[1] = lep1;

	cx_cross_sections.btfus_3d.setup_cross_section(btfus_3d,npoints_d,last_grid_point_d,nranges_d,
																			energies_in_d,energy_limit,dimfacts,dimidx,dimbidx,dimbidy,dimbidz,ndims);


*/
}

__host__
void XPTextureGrid::fill2DLayered(double* data_in,enum XPgridlocation location = XPgridlocation_host)
{
	int nx = 1;
	int ny = 1;
	int nz = 1;

	nx = gridparams.griddims[0];

	if(ndims+tdims > 1)
		ny = gridparams.griddims[1];

	if(ndims+tdims >2)
	{
		for(int i = 2;i<(ndims+tdims);i++)
		{
			nz *= gridparams.griddims[i];
		}
	}

	unsigned int nelements = nx*ny*nz;

	double* data_in_d;
	realkind* data_temp_d;

	cudaError status;

	cudaExtent extent = make_cudaExtent(nx,ny,nz);

	cudaMemcpy3DParms params = {0};
	params.kind = cudaMemcpyDeviceToDevice;

	cudaMalloc((void**)&data_temp_d,nelements*sizeof(realkind));

	if(location == XPgridlocation_host)
	{
		// data not in device memory
		cudaMalloc((void**)&data_in_d,nelements*sizeof(double));

		cudaMemcpy(data_in_d,data_in,nelements*sizeof(double),cudaMemcpyHostToDevice);
	}
	else
	{
		// data already in device memory
		data_in_d = data_in;
	}


	cudaMemcpydoubletorealkind(data_temp_d,data_in_d,nelements);

#ifdef __double_precision
	cudaChannelFormatDesc desc = cudaCreateChannelDesc(32,32,0,0,cudaChannelFormatKindSigned);
#else
	cudaChannelFormatDesc desc = cudaCreateChannelDesc<realkind>();
#endif

	status = cudaMalloc3DArray(&cuArray,&desc,extent,cudaArrayLayered);

	params.srcPtr.ptr = (void**)data_temp_d;
	params.srcPtr.pitch = nx*sizeof(realkind);
	params.srcPtr.xsize = nx;
	params.srcPtr.ysize = ny;
	params.dstArray = cuArray;
	params.extent = extent;

	cudaDeviceSynchronize();
	CUDA_SAFE_CALL(cudaMemcpy3D(&params));

	cudaDeviceSynchronize();
	const textureReference* texRefPtr;
	cudaGetTextureReference(&texRefPtr, symbol);
	cudaChannelFormatDesc channelDesc;
	cudaGetChannelDesc(&channelDesc, cuArray);
	CUDA_SAFE_CALL(cudaBindTextureToArray(texRefPtr, cuArray, &channelDesc));

	cudaFree(data_in_d);
	cudaFree(data_temp_d);
}

__host__
void XPTextureGrid::fill2D(cudaMatrixr data_in)
{

	texturetype = XPtex2D;

	int nx = 1;
	int ny = 1;

	char* texrefstring = (char*)malloc(sizeof(char)*30);
	char* texfetchstring = (char*)malloc(sizeof(char)*30);

	int itemp = next_tex2D;
	next_tex2D++;


	sprintf(texrefstring,"texref2D%i",itemp);
	sprintf(texfetchstring,"fetchtexref2DPtr%i",itemp);
	my_array_reference = itemp;
	symbol = texrefstring;

	CUDA_SAFE_CALL(cudaMemcpyFromSymbol(&pt2Function,texfetchstring,sizeof(texFunctionPtr)));

	nx = gridparams.griddims[0];
	ny = gridparams.griddims[1];

	printf(" fill2D nx = %i, ny = %i \n", nx,ny);

	cudaError status;

	cudaExtent extent = make_cudaExtent(nx,ny,0);

	cudaMemcpy3DParms params = {0};
	params.kind = cudaMemcpyDeviceToDevice;

	params.kind = cudaMemcpyDeviceToDevice;
#ifdef __double_precision
	cudaChannelFormatDesc desc = cudaCreateChannelDesc(32,32,0,0,cudaChannelFormatKindSigned);
#else
	cudaChannelFormatDesc desc = cudaCreateChannelDesc<realkind>();
#endif

	CUDA_SAFE_CALL(cudaMalloc3DArray(&cuArray,&desc,extent));

	params.srcPtr = data_in.getptr();
	params.dstArray = cuArray;
	params.extent = make_cudaExtent(nx,ny,1);

	cudaDeviceSynchronize();
	CUDA_SAFE_CALL(cudaMemcpy3D(&params));

	cudaDeviceSynchronize();
	const textureReference* texRefPtr;
	CUDA_SAFE_CALL(cudaGetTextureReference(&texRefPtr, symbol));
	cudaChannelFormatDesc channelDesc;
	CUDA_SAFE_CALL(cudaGetChannelDesc(&channelDesc, cuArray));
	CUDA_SAFE_KERNEL(cudaBindTextureToArray(texRefPtr, cuArray, &channelDesc));


}

__host__
void XPTextureGrid::fill1DLayered(double* data_in,enum XPgridlocation location = XPgridlocation_host)
{
	int nx = 1;
	int ny = 1;

	nx = gridparams.griddims[0];

	if(ndims+tdims > 1)
	{
		for(int i = 1;i<(ndims+tdims);i++)
		{
			ny *= gridparams.griddims[i];
		}
	}

	unsigned int nelements = nx*ny;

	double* data_in_d;
	realkind* data_temp_d;

	cudaError status;

	cudaExtent extent = make_cudaExtent(nx,0,ny);

	cudaMemcpy3DParms params = {0};
	params.kind = cudaMemcpyDeviceToDevice;

	cudaMalloc((void**)&data_temp_d,nelements*sizeof(realkind));

	if(location == XPgridlocation_host)
	{
		// data not in device memory
		cudaMalloc((void**)&data_in_d,nelements*sizeof(double));

		cudaMemcpy(data_in_d,data_in,nelements*sizeof(double),cudaMemcpyHostToDevice);
	}
	else
	{
		// data already in device memory
		data_in_d = data_in;
	}

	cudaMemcpydoubletorealkind(data_temp_d,data_in_d,nelements);

#ifdef __double_precision
	cudaChannelFormatDesc desc = cudaCreateChannelDesc(32,32,0,0,cudaChannelFormatKindSigned);
#else
	cudaChannelFormatDesc desc = cudaCreateChannelDesc<realkind>();
#endif

	status = cudaMalloc3DArray(&cuArray,&desc,extent,cudaArrayLayered);

	params.srcPtr.ptr = (void**)data_temp_d;
	params.srcPtr.pitch = nx*sizeof(realkind);
	params.srcPtr.xsize = nx;
	params.srcPtr.ysize = 1;
	params.dstArray = cuArray;
	params.extent = make_cudaExtent(nx,1,ny);

	cudaDeviceSynchronize();
	CUDA_SAFE_CALL(cudaMemcpy3D(&params));

	cudaDeviceSynchronize();
	const textureReference* texRefPtr;
	cudaGetTextureReference(&texRefPtr, symbol);
	cudaChannelFormatDesc channelDesc;
	cudaGetChannelDesc(&channelDesc, cuArray);
	CUDA_SAFE_CALL(cudaBindTextureToArray(texRefPtr, cuArray, &channelDesc));

	cudaFree(data_in_d);
	cudaFree(data_temp_d);
}



__global__
void map_transp_zones(cudaMatrixr transp_zone,XPTextureGrid xi_map,
										int lcenter,int lep1,int nzones,int nr,int nz)
{
	unsigned int idx = threadIdx.x;
	unsigned int idy = threadIdx.y;
	unsigned int gidx = blockIdx.x*blockDim.x+idx;
	unsigned int gidy = blockIdx.y*blockDim.y+idy;

	realkind temp_transp_zone;
	realkind xi;
	__shared__ realkind2 gridspacing;
	__shared__ realkind rmin;
	__shared__ realkind zmin;
	realkind r;
	realkind z;

	if(idx+idy == 0)
	{
		rmin = xi_map.gridparams.origin[0];
		zmin = xi_map.gridparams.origin[1];
		gridspacing.x = xi_map.gridparams.gridspacing[0];
		gridspacing.y = xi_map.gridparams.gridspacing[1];
	}
	__syncthreads();
	r = gidx*gridspacing.x+rmin;
	z = gidy*gridspacing.y+zmin;

	if((gidx < nr)&&(gidy < nz))
	{
		xi = xi_map(r,z);
		temp_transp_zone = lcenter+xi*nzones;
		temp_transp_zone = fmin((realkind)lep1,temp_transp_zone);

		transp_zone(gidx,gidy) = temp_transp_zone;

	}

}

__global__
void map_beam_zones(cudaMatrixr beam_zone,XPTextureGrid xi_map,XPTextureGrid theta_map,
										int lcenter,int nznbmr,double xminbm,simple_XPgrid<int,1> nthzsm,
										int nlsym2b,int nrow_zones,double thbdy0,int nr,int nz)
{
	unsigned int idx = threadIdx.x;
	unsigned int idy = threadIdx.y;
	unsigned int gidx = blockIdx.x*blockDim.x+idx;
	unsigned int gidy = blockIdx.y*blockDim.y+idy;

	realkind xi;
	realkind theta;
	realkind temp_beam_zone;
	realkind ibrf;
	int ibr0;
	int ibr1;
	int ibr;
	int inz0;
	int inz;
	int inz1;

	realkind inzf;
	realkind inz0f;
	__shared__ realkind2 gridspacing;
	__shared__ realkind rmin;
	__shared__ realkind zmin;
	realkind r;
	realkind z;

	if(idx+idy == 0)
	{
		rmin = xi_map.gridparams.origin[0];
		zmin = xi_map.gridparams.origin[1];
		gridspacing.x = xi_map.gridparams.gridspacing[0];
		gridspacing.y = xi_map.gridparams.gridspacing[1];
	}
	__syncthreads();
	r = gidx*gridspacing.x+rmin;
	z = gidy*gridspacing.y+zmin;

	if((gidx < nr)&&(gidy < nz))
	{
		xi = xi_map(r,z);
		theta = theta_map(r,z);

		ibrf = (lcenter+nznbmr*(xi/xminbm));

		ibr0 = max(1,min((int)rint(ibrf)-1,nrow_zones));
		inz0 = nthzsm(ibr0-1);
		ibr = max(1,min((int)rint(ibrf),nrow_zones));
		inz = nthzsm(ibr-1);
		ibr1 = max(1,min((int)rint(ibrf)+1,nrow_zones));
		inz1 = nthzsm(ibr1-1);

		inz0f = (inz-inz0)*(ibrf-ibr0)+inz0;
		inzf = (inz1-inz)*(ibrf-ibr)+inz;

		if(nlsym2b)
			temp_beam_zone = min(inzf,(inz0f+1+(abs(theta)/pi)*(inzf-inz0f)));
		else
			temp_beam_zone = min(inzf,(inz0f+1+((theta-thbdy0)*0.5/pi)*(inzf-inz0f)));

		beam_zone(gidx,gidy) = temp_beam_zone;

	}
}


__host__
void Environment::setup_transp_zones(void)
{
	cudaError status;
	dim3 cudaGridSize((nr+16-1)/16,(nz+16-1)/16,1);
	dim3 cudaBlockSize(16,16,1);

	cudaMatrixr temp_data(nr,nz);

	int lcenter = lcenter_transp;
	int nznbmr = nxi_rows;
	int lep1 = ledge_transp+1;
	int nlsym2b = midplane_symetry;

	double xminbm = xi_boundary;
	double thbdy0 = theta_body0;

	transp_zone.gridparams.griddims[0] = nr;
	transp_zone.gridparams.griddims[1] = nz;
	transp_zone.gridparams.origin[0] = Rmin;
	transp_zone.gridparams.origin[1] = Zmin;
	transp_zone.gridparams.gridspacing[0] = (Rmax-Rmin)/nr;
	transp_zone.gridparams.gridspacing[1] = (Zmax-Zmin)/nz;

	beam_zone.gridparams.griddims[0] = nr;
	beam_zone.gridparams.griddims[1] = nz;
	beam_zone.gridparams.origin[0] = Rmin;
	beam_zone.gridparams.origin[1] = Zmin;
	beam_zone.gridparams.gridspacing[0] = (Rmax-Rmin)/nr;
	beam_zone.gridparams.gridspacing[1] = (Zmax-Zmin)/nz;

	CUDA_SAFE_KERNEL((map_transp_zones<<<cudaGridSize,cudaBlockSize>>>(temp_data,
																				Xi_map,lcenter,lep1,nzones,nr,nz)));
	cudaDeviceSynchronize();

	transp_zone.fill2D(temp_data);

	CUDA_SAFE_KERNEL((map_beam_zones<<<cudaGridSize,cudaBlockSize>>>(temp_data,
																				Xi_map,Theta_map,lcenter,nznbmr,xminbm,
																				ntheta_row_zones,nlsym2b,nrow_zones,thbdy0,
																				nr,nz)));
	cudaDeviceSynchronize();

	beam_zone.fill2D(temp_data);

	cudaDeviceSynchronize();

	temp_data.cudaMatrixFree();

}


__host__
void Environment::allocate_Grids(void)
{

	int2 griddims_out;
	int mj = ntransp_zones;
	int mig = nthermal_species;
	int mimxbz = nbeam_zones;
	int mimxbzf = nbeam_zones_inside;
	int miz = zonebdyctr_shift_index;
	int mibs = max_species;
	int mib = nbeams;
	int ndifbe = n_diffusion_energy_bins;



	griddims_out.x = nr;
	griddims_out.y = nz;

	cudaMatrixr xigrid_temp(nxi,1,1);
	cudaMatrixr thgrid_temp(nth,1,1);
	cudaDeviceSynchronize();
	cudaError status = cudaGetLastError();
	if(status != cudaSuccess){fprintf(stderr, " allocate matrices %s\n", cudaGetErrorString(status));}

	xigrid = xigrid_temp;
	thgrid = thgrid_temp;

	Psispline.allocate(griddims_out,XPgridlocation_device);
	gspline.allocate(griddims_out,XPgridlocation_device);
	Phispline.allocate(griddims_out,XPgridlocation_device);

	rspline.allocate(nth,nint);
	rsplinex.allocate(nth,next);
	zspline.allocate(nth,nint);
	zsplinex.allocate(nth,next);

	Xi_bloated.allocate(lcenter_transp+xi_boundary*nzones+1);
	ntheta_row_zones.allocate(nrow_zones);

	background_density.allocate(mj,mig,miz);
	omega_wall_neutrals.allocate(mig,mj);
	omega_thermal_neutrals.allocate(mig,mimxbz);
	beamcx_neutral_density.allocate(mimxbz,mibs);
	beamcx_neutral_velocity.allocate(mimxbz,mibs);
	beamcx_neutral_energy.allocate(mimxbz,mibs);
	species_atomic_number.allocate(mibs);
	grid_zone_volume.allocate(mimxbz);
	beam_1stgen_neutral_density2d.allocate(mib,3,2,mimxbzf);

	injection_rate.allocate(mib);

	beam_ion_initial_velocity.allocate(3,mib);
	beam_ion_velocity_direction.allocate(mib,3,2,mimxbzf);

	toroidal_beam_velocity.allocate(mimxbz,mibs);
	average_beam_weight.allocate(mj,mibs);

	is_fusion_product.allocate(mibs);

	electron_temperature.allocate(mj,miz);
	ion_temperature.allocate(mj,miz);
	injection_energy.allocate(mibs);
	FPcoeff_arrayC.allocate(mj,mibs,4);
	FPcoeff_arrayD.allocate(mj,mibs,4);
	FPcoeff_arrayE.allocate(mj,mibs,4);

	loop_voltage.allocate(mj);
	current_shielding.allocate(mj);
	thermal_velocity.allocate(mj,mibs);

	adif_multiplier.allocate(20,max(ndifbe,1));
	adif_energies.allocate(20,max(ndifbe,1));

}

template<typename T,int dims>
__host__
void simple_XPgrid<T,dims>::copyFromDouble(double* data_in,enum cudaMemcpyKind kind)
{

	cudaMemcpydoubletoMatrixr(data,data_in);

	return;
}

__host__
void Environment::setup_fields(double** data_in,int** idata_in)
{
	double* Psispline_in = data_in[0];
	double* gspline_in = data_in[1];
	double* Phispline_in = data_in[2];
	double* Xi_map_in = data_in[3];
	double* Theta_map_in = data_in[4];
	double* omegag = data_in[5];
	double* rhob = data_in[6];
	double* owall0 = data_in[7];
	double* ovol02 = data_in[8];
	double* bn0x2p = data_in[9];
	double* bv0x2p = data_in[10];
	double* be0x2p = data_in[11];
	double* xzbeams = data_in[12];
	double* bmvol = data_in[13];
	double* bn002 = data_in[14];
	double* xninja = data_in[15];
	double* viona = data_in[16];
	double* vcxbn0 = data_in[17];
	double* vbtr2p = data_in[18];
	double* wbav = data_in[19];

	double* xiblo = data_in[20];
	double* dxi1 = data_in[21];
	double* dxi2 = dxi1+ntransp_zones;

	double* te = data_in[22];
	double* ti = data_in[23];
	double* einjs = data_in[24];
	double* cfa = data_in[25];
	double* dfa = data_in[26];
	double* efa = data_in[27];
	double* vpoh = data_in[28];
	double* xjbfac = data_in[29];
	double* vmin = data_in[30];
	double* velb_fi = data_in[31];
	double* difb_fi = data_in[32];
	double* velb_bi = data_in[33];
	double* difb_bi = data_in[34];
	double* fdifbe = data_in[35];
	double* edifbe = data_in[36];

	double* rspline_in = data_in[37];
	double* zspline_in = data_in[38];
	double* rsplinex_in = data_in[39];
	double* zsplinex_in = data_in[40];

	double* xigrid_in = data_in[41];
	double* thgrid_in = data_in[42];

	double* spacingparams = data_in[43];
	double* limiter_map_in = data_in[44];
	double* ympx_in = data_in[45];

	int* nlfprod = idata_in[0];
	int* nthzsm = idata_in[1];

	realkind simple_gridspacing[6] = {1,1,1,1,1,1};
	realkind simple_origins[6] = {0,0,0,0,0,0};

	int tex_griddims[2] = {nr,nz};
	realkind tex_gridspacing[2] = {gridspacing.x,gridspacing.y};
	realkind tex_origin[2] = {Rmin,Zmin};

	size_t free = 0;
	size_t total = 0;

	xispani = spacingparams[5];
	thspani = spacingparams[4];

	transp_zone.tdims = 2;
	beam_zone.tdims = 2;
	Xi_map.tdims = 2;
	Theta_map.tdims = 2;
	rotation.tdims = 2;
	fusion_anomalous_radialv.tdims = 2;
	fusion_anomalous_diffusion.tdims = 2;
	beam_anomalous_radialv.tdims = 2;
	beam_anomalous_diffusion.tdims = 2;
	dxi_spacing1.tdims = 2;
	dxi_spacing2.tdims = 2;
	limiter_map.tdims = 2;
	Ymidplane.tdims = 2;

	transp_zone.setup_dims(tex_griddims,tex_gridspacing,tex_origin);
	beam_zone.setup_dims(tex_griddims,tex_gridspacing,tex_origin);
	Xi_map.setup_dims(tex_griddims,tex_gridspacing,tex_origin);
	Theta_map.setup_dims(tex_griddims,tex_gridspacing,tex_origin);
	rotation.setup_dims(tex_griddims,tex_gridspacing,tex_origin);
	fusion_anomalous_radialv.setup_dims(tex_griddims,tex_gridspacing,tex_origin);
	fusion_anomalous_diffusion.setup_dims(tex_griddims,tex_gridspacing,tex_origin);
	beam_anomalous_radialv.setup_dims(tex_griddims,tex_gridspacing,tex_origin);
	beam_anomalous_diffusion.setup_dims(tex_griddims,tex_gridspacing,tex_origin);
	dxi_spacing1.setup_dims(tex_griddims,tex_gridspacing,tex_origin);
	dxi_spacing2.setup_dims(tex_griddims,tex_gridspacing,tex_origin);
	limiter_map.setup_dims(tex_griddims,tex_gridspacing,tex_origin);
	Ymidplane.setup_dims(tex_griddims,tex_gridspacing,tex_origin);

/*
	cudaMalloc((void**)&limiter_map_in_d,nr*nz*sizeof(double));
	cudaMalloc((void**)&xigrid_in_d,nxi*sizeof(double));
	cudaMalloc((void**)&thgrid_in_d,nth*sizeof(double));

	cudaMalloc((void**)&Xi_map_d,nr*nz*sizeof(double));
	cudaMalloc((void**)&Theta_map_d,nr*nz*sizeof(double));

	CUDA_SAFE_CALL(cudaMemcpy(Xi_map_d,Xi_map_in,nr*nz*sizeof(double),cudaMemcpyHostToDevice));
	CUDA_SAFE_CALL(cudaMemcpy(Theta_map_d,Theta_map_in,nr*nz*sizeof(double),cudaMemcpyHostToDevice));
	CUDA_SAFE_CALL(cudaMemcpy(limiter_map_in_d,limiter_map_in,nr*nz*sizeof(double),cudaMemcpyHostToDevice));

	CUDA_SAFE_CALL(cudaMemcpy(xigrid_in_d,xigrid_in,nxi*sizeof(double),cudaMemcpyHostToDevice));
	CUDA_SAFE_CALL(cudaMemcpy(thgrid_in_d,thgrid_in,nth*sizeof(double),cudaMemcpyHostToDevice));
	*/

	cudaMatrixr Xi_map_temp(nr,nz);
	cudaMatrixr Theta_map_temp(nr,nz);
	cudaMatrixr limiter_map_temp(nr,nz);

	CUDA_SAFE_KERNEL(allocate_Grids());

	CUDA_SAFE_KERNEL(ntheta_row_zones.setupi(nthzsm,simple_gridspacing,simple_origins));

	cudaMemGetInfo(&free,&total);
	printf("Free Memory = %i mb\nUsed mememory = %i mb\n",(int)(free)/(1<<10),(int)(total-free)/(1<<10));

	cudaMemcpydoubletoMatrixr(xigrid,xigrid_in);
	cudaMemcpydoubletoMatrixr(thgrid,thgrid_in);


	printf("setting up Psispline \n");
	Psispline.gridspacing = gridspacing;
	Psispline.setup(Psispline_in,Rmin,Rmax,Zmin,Zmax);
	printf("setting up gspline \n");
	gspline.gridspacing = gridspacing;
	gspline.setup(gspline_in,Rmin,Rmax,Zmin,Zmax);
	printf("setting up phispline \n");
	Phispline.gridspacing = gridspacing;
	Phispline.setup(Phispline_in,Rmin,Rmax,Zmin,Zmax);

	printf("setting up rspline \n");
	rspline.setup(rspline_in,thgrid,xigrid,
				nbsii,nbsjj,spacingparams[0],spacingparams[2],
	  	  	  spacingparams[1],spacingparams[3],
	  	  	  spacingparams[4],spacingparams[5]);

	printf("setting up rsplinex \n");
	rsplinex.setup(rsplinex_in,thgrid,xigrid,
				nbsii,nbsjj,spacingparams[0],spacingparams[2],
	  	  	  spacingparams[1],spacingparams[3],
	  	  	  spacingparams[4],spacingparams[5]);

	printf("setting up zspline \n");
	zspline.setup(zspline_in,thgrid,xigrid,
				nbsii,nbsjj,spacingparams[0],spacingparams[2],
	  	  	  spacingparams[1],spacingparams[3],
	  	  	  spacingparams[4],spacingparams[5]);

	printf("setting up zsplinex \n");
	zsplinex.setup(zsplinex_in,thgrid,xigrid,
				nbsii,nbsjj,spacingparams[0],spacingparams[2],
	  	  	  spacingparams[1],spacingparams[3],
	  	  	  spacingparams[4],spacingparams[5]);

	setupBfield();

	cudaMemcpydoubletoMatrixr(Xi_map_temp,Xi_map_in);
	cudaMemcpydoubletoMatrixr(Theta_map_temp,Theta_map_in);
	cudaMemcpydoubletoMatrixr(limiter_map_temp,limiter_map_in);

	printf("setting up Xi_map \n");
	Xi_map.fill2D(Xi_map_temp);
	printf("setting up Theta_map \n");
	Theta_map.fill2D(Theta_map_temp);
	printf("setting up limiter_map \n");
	limiter_map.fill2D(limiter_map_temp);

	Xi_map_temp.cudaMatrixFree();
	Theta_map_temp.cudaMatrixFree();
	limiter_map_temp.cudaMatrixFree();


	printf("setting up transp zones \n");
	setup_transp_zones();

	Xi_bloated.setup(xiblo,simple_gridspacing,simple_origins);

	cudaMatrixr dxi_spacing1_temp = mapTransp_data_to_RZ(dxi1);
	dxi_spacing1.fill2D(dxi_spacing1_temp);
	dxi_spacing1_temp.cudaMatrixFree();

	cudaMatrixr dxi_spacing2_temp = mapTransp_data_to_RZ(dxi2);
	dxi_spacing2.fill2D(dxi_spacing2_temp);
	dxi_spacing2_temp.cudaMatrixFree();

	cudaMatrixr rotation_temp = mapTransp_data_to_RZ(omegag);
	rotation.fill2D(rotation_temp);
	rotation_temp.cudaMatrixFree();

	cudaMatrixr velb_fi_temp = mapTransp_data_to_RZ(velb_fi);
	fusion_anomalous_radialv.fill2D(velb_fi_temp);
	velb_fi_temp.cudaMatrixFree();

	cudaMatrixr difb_fi_temp = mapTransp_data_to_RZ(difb_fi);
	fusion_anomalous_diffusion.fill2D(difb_fi_temp);
	difb_fi_temp.cudaMatrixFree();

	cudaMatrixr velb_bi_temp = mapTransp_data_to_RZ(velb_bi);
	beam_anomalous_radialv.fill2D(velb_bi_temp);
	velb_bi_temp.cudaMatrixFree();

	cudaMatrixr difb_bi_temp = mapTransp_data_to_RZ(difb_bi);
	beam_anomalous_diffusion.fill2D(difb_bi_temp);
	difb_bi_temp.cudaMatrixFree();

	cudaMatrixr ympx_temp = mapTransp_data_to_RZ(ympx_in,1,1);
	Ymidplane.fill2D(ympx_temp);
	ympx_temp.cudaMatrixFree();


	background_density.setup(rhob,simple_gridspacing,simple_origins);
	omega_wall_neutrals.setup(owall0,simple_gridspacing,simple_origins);
	beamcx_neutral_density.setup(bn0x2p,simple_gridspacing,simple_origins);
	beamcx_neutral_velocity.setup(bv0x2p,simple_gridspacing,simple_origins);
	beamcx_neutral_energy.setup(be0x2p,simple_gridspacing,simple_origins);
	species_atomic_number.setup(xzbeams,simple_gridspacing,simple_origins);
	grid_zone_volume.setup(bmvol,simple_gridspacing,simple_origins);
	beam_1stgen_neutral_density2d.setup(bn002,simple_gridspacing,simple_origins);
	injection_rate.setup(xninja,simple_gridspacing,simple_origins);
	beam_ion_initial_velocity.setup(viona,simple_gridspacing,simple_origins);
	beam_ion_velocity_direction.setup(vcxbn0,simple_gridspacing,simple_origins);

	toroidal_beam_velocity.setup(vbtr2p,simple_gridspacing,simple_origins);

	average_beam_weight.setup(wbav,simple_gridspacing,simple_origins);

	is_fusion_product.setupi(nlfprod,simple_gridspacing,simple_origins);

	electron_temperature.setup(te,simple_gridspacing,simple_origins);
	ion_temperature.setup(ti,simple_gridspacing,simple_origins);
	injection_energy.setup(einjs,simple_gridspacing,simple_origins);
	FPcoeff_arrayC.setup(cfa,simple_gridspacing,simple_origins);
	FPcoeff_arrayD.setup(dfa,simple_gridspacing,simple_origins);
	FPcoeff_arrayE.setup(efa,simple_gridspacing,simple_origins);
	loop_voltage.setup(vpoh,simple_gridspacing,simple_origins);
	current_shielding.setup(xjbfac,simple_gridspacing,simple_origins);
	thermal_velocity.setup(vmin,simple_gridspacing,simple_origins);
	printf(" adif_multiplier \n");
	adif_multiplier.setup(fdifbe,simple_gridspacing,simple_origins);
	printf(" adif_energies \n");
	adif_energies.setup(edifbe,simple_gridspacing,simple_origins);

}

__global__
void mapTransp_data_to_RZ_kernel(cudaMatrixr data_out,cudaMatrixd data_in,
															 XPTextureGrid Xi_map,simple_XPgrid<realkind,1> Xi_bloated,
															 int nr,int nz,int ledge,realkind xi_boundary,int nzones,int lcenter,int bloated)
{
	unsigned int idx = threadIdx.x;
	unsigned int idy = threadIdx.y;
	unsigned int idz = threadIdx.z;
	unsigned int gidx = idx+blockIdx.x*blockDim.x;
	unsigned int gidy = idy+blockIdx.y*blockDim.y;
	unsigned int gidz = idz+blockIdx.z*blockDim.z;

	realkind xi;
	int ngc;
	int ngcx;
	realkind xingc;
	realkind r = gidx*Xi_map.gridparams.gridspacing[0]+Xi_map.gridparams.origin[0];
	realkind z = gidy*Xi_map.gridparams.gridspacing[1]+Xi_map.gridparams.origin[1];
	realkind data_out_temp;

	xi = Xi_map(r,z);

	ngcx = (int)(lcenter+xi*nzones);
	ngc = min(ledge+1,ngcx);

	xingc = (xi-Xi_bloated((realkind)ngcx))/(Xi_bloated(realkind(ngcx+1))-Xi_bloated(realkind(ngcx)));
	xingc = max(0.0,min(1.0,xingc));

	if(ngc > ledge)
	{
		xingc = 0.0;
	}

	if(!bloated)
	{
		data_out_temp = data_in(ngc,gidz)+xingc*(data_in(ngc+1,gidz)-data_in(ngc,gidz));
	}
	else
	{
		data_out_temp = data_in(ngcx,gidz)+xingc*(data_in(ngcx+1,gidz)-data_in(ngcx,gidz));
	}

	if((gidx<nr)&&(gidy<nz))
	{
		data_out(gidx,gidy,gidz) = data_out_temp;
	}


	return;

}

__host__
cudaMatrixr Environment::mapTransp_data_to_RZ(double* data_in_h,int ndim3,int bloated)
{
	dim3 cudaGridSize(1,1,1);
	dim3 cudaBlockSize(16,16,1);
	int data_size;

	if(bloated == 0)
		data_size = ntransp_zones;
	else
		data_size = 2*ntransp_zones;

	cudaMatrixd data_in_temp(data_size,ndim3);

	data_in_temp.cudaMatrixcpy(data_in_h,cudaMemcpyHostToDevice);

	cudaMatrixr data_out(nr,nz,ndim3);


	if(ndim3 > 1)
	{
		cudaBlockSize.x = 8;
		cudaBlockSize.y = 8;
		cudaBlockSize.z = 8;
	}

	cudaGridSize.x = (cudaBlockSize.x+nr-1)/cudaBlockSize.x;
	cudaGridSize.y = (cudaBlockSize.y+nz-1)/cudaBlockSize.y;
	cudaGridSize.z = (cudaBlockSize.z+ndim3-1)/cudaBlockSize.z;

	CUDA_SAFE_KERNEL((mapTransp_data_to_RZ_kernel<<<cudaGridSize,cudaBlockSize>>>(
								data_out,data_in_temp,Xi_map,Xi_bloated,nr,nz,ledge_transp,xi_boundary,
								nzones,lcenter_transp,bloated)));
	cudaDeviceSynchronize();

	data_in_temp.cudaMatrixFree();
	return data_out;

}


__global__
void check_environment_kernel(Environment* plasma_in)
{
	unsigned int idx = threadIdx.x;
	unsigned int idy = threadIdx.y;
	unsigned int gidx = idx + blockIdx.x*blockDim.x;


	realkind r;
	realkind z;
	realkind xi;
	realkind theta;
	int nr = plasma_in -> nr;
	int nz = plasma_in -> nz;
	int n = plasma_in -> nxi;
	int m = plasma_in -> nth;

	realkind2 gridspacing;
	realkind2 origins;
	realkind rmin = plasma_in -> Rmin;
	realkind rmax = plasma_in -> Rmax;
	realkind zmin = plasma_in -> Zmin;
	realkind zmax = plasma_in -> Zmax;
	realkind3 Bfield;
	int rindex;
	int zindex;
	realkind max_energy = plasma_in->cx_cross_sections.max_energy;

	realkind2 spline_params;
	int2 spline_index;
	origins.x = plasma_in->Xi_map.gridparams.origin[0];
	origins.y = plasma_in->Xi_map.gridparams.origin[1];
	gridspacing.x = plasma_in->gridspacing.x;
	gridspacing.y = plasma_in->gridspacing.y;
	realkind c0,c1,c2,c3;
	size_t pitch = plasma_in -> Psispline.pitch;

	int transp_zone;
	float limiter_distance;
	realkind cx_data;

	BCspline* psispline;
	realkind my_energy;


	//printf("texture spacings /n gridspacing = %f, %f \n origins = %f, %f \n",
	//		plasma_in->Xi_map.gridparams.gridspacing[0],plasma_in->Xi_map.gridparams.gridspacing[1],
		//	plasma_in->Xi_map.gridparams.origin[0],plasma_in->Xi_map.gridparams.origin[1]);



	if(gidx == 0)
	{
		for(int i=0;i<nr;i+=8)
		{
			for(int j=0;j<nz;j+=8)
			{/*
				for(int k=0;k<512/10;k++)
				{
					for(int l=0;l<plasma_in->nspecies;l+=10)
					{
						my_energy = ((realkind)k)/(512.0);
						my_energy = max_energy*(exp10(4.0*my_energy-4.0)-0.0001);
						printf("Energy = %14.10g, @(%i,%i,%i,%i)\n",my_energy,i,j,k,l);



						cx_data = plasma_in->cx_cross_sections.cx_thcx_halo(my_energy,j,i,l);


						printf("data = %14.10g \n",cx_data);

					}
				}
			 	 */

				r = ((realkind)i+0.5)*gridspacing.x+rmin;
				z = ((realkind)j+0.5)*gridspacing.y+zmin;

				printf("i = %i, j = %i \n",i,j);
				printf("r = %14.10f, z = %14.10f \n",r,z);

				spline_index = plasma_in -> Psispline.findindex(r,z);

				printf("index check = %i, %i\n",spline_index.x,spline_index.y);
			//	transp_zone = plasma_in -> transp_zone(r,z);
				//limiter_distance = plasma_in -> limiter_map(r,z);


/*
				xi = plasma_in -> Xi_map(r,z);
				theta = plasma_in -> Theta_map(r,z);
				printf("xi = %10.7f, theta = %10.7f \n",xi,theta);

				plasma_in -> polarintrp(xi,theta,&spline_params,&spline_index);

				if(spline_index.y >= (plasma_in -> nint-1))
				{
					spline_index.y -= (plasma_in -> nint-1);
					r = plasma_in -> rsplinex.BCspline_eval<XPgridderiv_f>(spline_index,spline_params);
					z = plasma_in -> zsplinex.BCspline_eval<XPgridderiv_f>(spline_index,spline_params);
				}
				else
				{
					r = plasma_in -> rspline.BCspline_eval<XPgridderiv_f>(spline_index,spline_params);
					z = plasma_in -> zspline.BCspline_eval<XPgridderiv_f>(spline_index,spline_params);
				}
				printf("r2 = %10.7f, z2 = %10.7f \n",r,z);

				//c0 = plasma_in -> Psispline.get_spline(i,j)[0];
				//c1 = plasma_in -> Psispline.get_spline(i,j)[1];
				//c2 = plasma_in -> Psispline.get_spline(i,j)[2];
				//c3 = plasma_in -> Psispline.get_spline(i,j)[3];
*/
				Bfield.x  = plasma_in -> Bfieldr(r,z);
				Bfield.y  = plasma_in -> Bfieldz(r,z);
				Bfield.z  = plasma_in -> Bfieldphi(r,z);

				//printf("Psispline = %14.10g, %14.10g, %14.10g, %14.10g \n",c0,c1,c2,c3);
				//c0 = plasma_in -> gspline.spline[i+j*pitch/sizeof(BCspline)][0];
				//c1 = plasma_in -> gspline.spline[i+j*pitch/sizeof(BCspline)][1];
				//c2 = plasma_in -> gspline.spline[i+j*pitch/sizeof(BCspline)][2];
				//c3 = plasma_in -> gspline.spline[i+j*pitch/sizeof(BCspline)][3];
				//printf("gspline = %10.7g, %10.7g, %10.7g, %10.7g \n",c0,c1,c2,c3);

				c0 = plasma_in -> Psispline.BCspline_eval<XPgridderiv_dfdx>(r,z);
				c1 = plasma_in -> Psispline.BCspline_eval<XPgridderiv_dfdy>(r,z);
				c2 = plasma_in -> gspline.BCspline_eval<XPgridderiv_f>(r,z);

				printf("dPsi,g = %14.10g, %14.10g, %14.10g \n",c0,c1,c2);

				c0 = plasma_in -> Psispline.BCspline_eval<XPgridderiv_dfdxx>(r,z);
				c1 = plasma_in -> Psispline.BCspline_eval<XPgridderiv_dfdyy>(r,z);
				c2 = plasma_in -> Psispline.BCspline_eval<XPgridderiv_dfdxy>(r,z);

				printf("ddPsi = %14.10g, %14.10g, %14.10g \n",c0,c1,c2);
				printf("B = %14.10g, %14.10g, %14.10g \n",Bfield.x,Bfield.y,Bfield.z);
				Bfield = plasma_in -> eval_Bvector(r,z);
				printf("B2 = %14.10g, %14.10g, %14.10g \n",Bfield.x,Bfield.y,Bfield.z);
				printf("---------------------------------------------------------\n");


/*



				plasma_in -> polarintrp(xi,theta,&spline_params,&spline_index);
				printf("spline index = (%i, %i) \nparams = %10.5f, %10.5f \n",spline_index.y,spline_index.x,spline_params.y,spline_params.x);

				if(spline_index.y >= ((plasma_in -> nint)-1))
				{
					printf("extended spline \n");
					spline_index.y -= (plasma_in -> nint-1);
					r = plasma_in -> rsplinex.BCspline_eval<XPgridderiv_f>(spline_index,spline_params);
					z = plasma_in -> zsplinex.BCspline_eval<XPgridderiv_f>(spline_index,spline_params);
				}
				else
				{
					r = plasma_in -> rspline.BCspline_eval<XPgridderiv_f>(spline_index,spline_params);
					z = plasma_in -> zspline.BCspline_eval<XPgridderiv_f>(spline_index,spline_params);
				}

				printf("Spline: R = %10.5f, Z = %10.5f \n -------------------------------------- \n",r,z);
*/
			}
		}
	}

}

__host__
void Environment::check_environment(void)
{
	Environment* plasma_d;
	CUDA_SAFE_CALL(cudaMalloc((void**)&plasma_d,sizeof(Environment)));
	CUDA_SAFE_CALL(cudaMemcpy(plasma_d,this,sizeof(Environment),cudaMemcpyHostToDevice));

	CUDA_SAFE_KERNEL((check_environment_kernel<<<1,1>>>(plasma_d)));
	cudaDeviceSynchronize();

	cudaFree(plasma_d);
}



__global__
void generate_limiter_bitmap(Environment* plasma_in,cudaMatrixf limiter_map_out)
{
	int DIM = 1024;
	float dim = DIM;
	unsigned int gidx = blockIdx.x*blockDim.x+threadIdx.x;
	unsigned int gidy = threadIdx.y+blockIdx.y*blockDim.y;

	float nr = plasma_in->nr;
	float nz = plasma_in -> nz;
	float x = gidx;
	float y = gidy;
	float r = (plasma_in ->gridspacing.x)*(nr*x/dim)+plasma_in->Rmin;
	float z = (plasma_in ->gridspacing.y)*(nz*y/dim)+plasma_in->Zmin;

	int rindex;
	int zindex;

	float Xi = plasma_in -> Xi_map(r,z);
	float Theta = plasma_in->Theta_map(r,z);
	float dxi;
	float dtheta;

	realkind2 spline_params;
	int2 spline_index;

	plasma_in -> polarintrp(Xi,Theta,&spline_params,&spline_index);

	float limiter_distance;
	float result;


	limiter_distance = plasma_in -> limiter_map(r,z);

	result = exp(-pow(limiter_distance,2));

	result = (exp(-pow(10.0*(spline_params.x-0.5),2))+exp(-pow(10.0*(spline_params.y-0.5),2)))/2.0f;



	if(Xi >= plasma_in -> xi_max)
	{
		result = 0;
	}

	printf("For pixel(%i,%i): result = %f\n",gidx,gidy,result);





	limiter_map_out(gidx,gidy) = result;


}

































