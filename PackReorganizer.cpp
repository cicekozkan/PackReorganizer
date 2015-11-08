//pack.h
#pragma once
#include <string>
#include <vector>


class Pack {
	std::vector<std::string> mpvec;
public:
	Pack() {}
	bool isInsertable(const std::string &cpair)const;
	int getSize()const { return mpvec.size();}
	void add(const std::string &cpair);
	void display()const;
	friend bool operator<(const Pack &p1, const Pack &p2){
		if (p1.getSize() != p2.getSize())
			return !(p1.getSize() < p2.getSize());
		return !(p1.mpvec < p2.mpvec);
	}
};


//pack.cpp

#include "pack.h"
#include <set>
#include <iostream>



using namespace std;

bool Pack::isInsertable(const std::string &cpair)const
{
	if (mpvec.size() == 4)
		return false;
	
	if (mpvec.empty())
		return true;
	set<string> checkset;

	for (const auto &s : mpvec) {
		checkset.insert(s.substr(0, 3));
		checkset.insert(s.substr(3, 3));
	}

	checkset.insert(cpair.substr(0, 3));
	checkset.insert(cpair.substr(3, 3));

	return checkset.size() == 2 * (mpvec.size() + 1);
}


void Pack::add(const std::string &cpair)
{
	mpvec.push_back(cpair);
}


void Pack::display()const
{
	for (const auto &s : mpvec)
		cout << s << "  ";
	cout << "\n" << endl;
}


//main.cpp
#include "pack.h"
#include <cstdlib>
#include <ctime>
#include <algorithm>
#include <iostream>





using namespace std;

string getRandomOrder()
{
	static const char * const mp[28] = { "EURUSD", "GBPUSD", "USDJPY", "USDCHF", "AUDUSD", "USDCAD", "NZDUSD",
		"EURGBP", "EURJPY", "EURCHF", "EURAUD", "EURCAD", "EURNZD",
		"GBPJPY", "GBPCHF", "GBPAUD", "GBPCAD", "GBPNZD",
		"CHFJPY", "AUDJPY", "CADJPY", "NZDJPY",
		"AUDCHF", "CADCHF", "NZDCHF",
		"AUDCAD", "NZDCAD",
		"AUDNZD" };
	return mp[rand() % 28];
}

//void sortPacks(vector<Pack> &pvec)

int main()
{
	srand(static_cast<unsigned>(time(nullptr)));
	vector<string> svec(500);
	generate_n(svec.begin(), 500, &getRandomOrder);

	vector<Pack> pvec(1);
	
	size_t k;
	
	for (const auto &s : svec) {
		for (k = 0; k < pvec.size(); k++) {
			if (pvec[k].isInsertable(s))
				break;
		}
		
		if (k == pvec.size()) {
			pvec.push_back(Pack());
			pvec.back().add(s);
		}
		else {
			pvec[k].add(s);
		}			
	}
	sort(pvec.begin(), pvec.end());
	for (const auto &p : pvec)
		p.display();

	return 0;

}

